module ogre.materials.pass;

import core.sync.mutex;
//import std.container;
import std.algorithm;
import std.string : indexOf;
import std.array;

import ogre.config;
import ogre.compat;
import ogre.general.common;
import ogre.general.colourvalue;
import ogre.exception;
import ogre.lod.lodstrategy;
import ogre.sharedptr;
import ogre.scene.userobjectbindings;
import ogre.general.root;
import ogre.materials.technique;
import ogre.materials.blendmode;
import ogre.scene.light;
import ogre.materials.textureunitstate;
import ogre.materials.gpuprogram;
import ogre.materials.autoparamdatasource;
import ogre.materials.material;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Materials
 *  @{
 */


/** Default pass hash function.
 @remarks
 Tries to minimise the number of texture changes.
 */
//struct MinTextureStateChangeHashFunc// : public Pass.HashFunc
//{
static uint MinTextureStateChangeHashFunc(Pass p)//
{
    synchronized(p.mTexUnitChangeMutex)
    {
        
        _StringHash H;
        uint hash = p.getIndex() << 28;
        size_t c = p.getNumTextureUnitStates();
        
        TextureUnitState t0,t1;
        if (c)
            t0 = p.getTextureUnitState(0);
        if (c > 1)
            t1 = p.getTextureUnitState(1);
        
        if (t0 && !t0.getTextureName().empty())
            hash += (cast(uint)(H(t0.getTextureName())) 
                     % (1 << 14)) << 14;
        if (t1 && !t1.getTextureName().empty())
            hash += (cast(uint)(H(t1.getTextureName()))
                     % (1 << 14));
        return hash;
    }
}
//};
//MinTextureStateChangeHashFunc sMinTextureStateChangeHashFunc;

/** Alternate pass hash function.
 @remarks
 Tries to minimise the number of GPU program changes.
 */
//struct MinGpuProgramChangeHashFunc : public Pass.HashFunc
//{
static uint MinGpuProgramChangeHashFunc(Pass p) //const
{
    synchronized(p.mGpuProgramChangeMutex)
    {
        _StringHash H;
        uint hash = p.getIndex() << 28;
        if (p.hasVertexProgram())
            hash += (cast(uint)(H(p.getVertexProgramName()))
                     % (1 << 14)) << 14;
        if (p.hasFragmentProgram())
            hash += (cast(uint)(H(p.getFragmentProgramName()))
                     % (1 << 14));
        return hash;
    }
}
//};
//MinGpuProgramChangeHashFunc sMinGpuProgramChangeHashFunc;

/// Categorisation of passes for the purpose of additive lighting
enum IlluminationStage
{
    /// Part of the rendering which occurs without any kind of direct lighting
    IS_AMBIENT,
    /// Part of the rendering which occurs per light
    IS_PER_LIGHT,
    /// Post-lighting rendering
    IS_DECAL, 
    /// Not determined
    IS_UNKNOWN
}

/** Class defining a single pass of a Technique (of a Material), i.e.
 a single rendering call.
 @remarks
 Rendering can be repeated with many passes for more complex effects.
 Each pass is either a fixed-function pass (meaning it does not use
 a vertex or fragment program) or a programmable pass (meaning it does
 use either a vertex and fragment program, or both).
 @par
 Programmable passes are complex to define, because they require custom
 programs and you have to set all constant inputs to the programs (like
 the position of lights, any base material colours you wish to use etc), but
 they do give you much total flexibility over the algorithms used to render your
 pass, and you can create some effects which are impossible with a fixed-function pass.
 On the other hand, you can define a fixed-function pass in very little time, and
 you can use a range of fixed-function effects like environment mapping very
 easily, plus your pass will be more likely to be compatible with older hardware.
 There are pros and cons to both, just remember that if you use a programmable
 pass to create some great effects, allow more time for definition and testing.
 */
class Pass// : public PassAlloc
{
public:
    /** Definition of a functor for calculating the hashcode of a Pass.
     @remarks
         The hashcode of a Pass is used to sort Passes for rendering, in order
         to reduce the number of render state changes. Each Pass represents a
         single unique set of states, but by ordering them, state changes can
         be minimised between passes. An implementation of this functor should
         order passes so that the elements that you want to keep constant are
         sorted next to each other.
     @see Pass.setHashFunc
     */
    alias uint function(Pass p) HashFunc;
    // You can pass struct with opCall implemented too ofcourse.
    /*struct HashFunc
    {
        uint opCall()(Pass p){ return 0s;}
        /// Need destructor in case subclasses use it
        ~this() {}
    }*/
protected:
    Technique mParent;
    ushort mIndex; // pass index
    string mName; // optional name for the pass
    uint mHash; // pass hash
    bool mHashDirtyQueued; // needs to be dirtied when next loaded
    //-------------------------------------------------------------------------
    // Colour properties, only applicable in fixed-function passes
    ColourValue mAmbient;
    ColourValue mDiffuse;
    ColourValue mSpecular;
    ColourValue mEmissive;
    Real mShininess;
    TrackVertexColour mTracking;
    //-------------------------------------------------------------------------
    
    //-------------------------------------------------------------------------
    // Blending factors
    SceneBlendFactor mSourceBlendFactor;
    SceneBlendFactor mDestBlendFactor;
    SceneBlendFactor mSourceBlendFactorAlpha;
    SceneBlendFactor mDestBlendFactorAlpha;
    
    // Used to determine if separate alpha blending should be used for color and alpha channels
    bool mSeparateBlend;
    
    //-------------------------------------------------------------------------
    // Blending operations
    SceneBlendOperation mBlendOperation;
    SceneBlendOperation mAlphaBlendOperation;
    
    // Determines if we should use separate blending operations for color and alpha channels
    bool mSeparateBlendOperation;
    
    //-------------------------------------------------------------------------
    
    //-------------------------------------------------------------------------
    // Depth buffer settings
    bool mDepthCheck;
    bool mDepthWrite;
    CompareFunction mDepthFunc;
    float mDepthBiasConstant;
    float mDepthBiasSlopeScale;
    float mDepthBiasPerIteration;
    
    // Colour buffer settings
    bool mColourWrite;
    
    // Alpha reject settings
    CompareFunction mAlphaRejectFunc;
    ubyte mAlphaRejectVal;
    bool mAlphaToCoverageEnabled;
    
    // Transparent depth sorting
    bool mTransparentSorting;
    // Transparent depth sorting forced
    bool mTransparentSortingForced;
    //-------------------------------------------------------------------------
    
    //-------------------------------------------------------------------------
    // Culling mode
    CullingMode mCullMode;
    ManualCullingMode mManualCullMode;
    //-------------------------------------------------------------------------
    
    /// Lighting enabled?
    bool mLightingEnabled;
    /// Max simultaneous lights
    ushort mMaxSimultaneousLights;
    /// Starting light index
    ushort mStartLight;
    /// Run this pass once per light?
    bool mIteratePerLight;
    /// Iterate per how many lights?
    ushort mLightsPerIteration;
    // Should it only be run for a certain light type?
    bool mRunOnlyForOneLightType;
    Light.LightTypes mOnlyLightType;
    // With a specific light mask?
    uint mLightMask;
    
    /// Shading options
    ShadeOptions mShadeOptions;
    /// Polygon mode
    PolygonMode mPolygonMode;
    /// Normalisation
    bool mNormaliseNormals;
    bool mPolygonModeOverrideable;
    //-------------------------------------------------------------------------
    // Fog
    bool mFogOverride;
    FogMode mFogMode;
    ColourValue mFogColour;
    Real mFogStart;
    Real mFogEnd;
    Real mFogDensity;
    //-------------------------------------------------------------------------
    
    /// Storage of texture unit states
    //typedef vector<TextureUnitState*>.type TextureUnitStates;
    alias TextureUnitState[] TextureUnitStates;
    TextureUnitStates mTextureUnitStates;
    
    // Vertex program details
    GpuProgramUsage mVertexProgramUsage;
    // Vertex program details
    GpuProgramUsage mShadowCasterVertexProgramUsage;
    // Fragment program details
    GpuProgramUsage mShadowCasterFragmentProgramUsage;
    // Vertex program details
    GpuProgramUsage mShadowReceiverVertexProgramUsage;
    // Fragment program details
    GpuProgramUsage mFragmentProgramUsage;
    // Fragment program details
    GpuProgramUsage mShadowReceiverFragmentProgramUsage;
    // Geometry program details
    GpuProgramUsage mGeometryProgramUsage;
    // Tesselation hull program details
    GpuProgramUsage mTesselationHullProgramUsage;
    // Tesselation domain program details
    GpuProgramUsage mTesselationDomainProgramUsage;
    // Compute program details
    GpuProgramUsage mComputeProgramUsage;
    // Is this pass queued for deletion?
    bool mQueuedForDeletion;
    // number of pass iterations to perform
    size_t mPassIterationCount;
    // point size, applies when not using per-vertex point size
    Real mPointSize;
    Real mPointMinSize;
    Real mPointMaxSize;
    bool mPointSpritesEnabled;
    bool mPointAttenuationEnabled;
    // constant, linear, quadratic coeffs
    Real[3] mPointAttenuationCoeffs;
    // TU Content type lookups
    alias ushort[] ContentTypeLookup;
    ContentTypeLookup mShadowContentTypeLookup;
    bool mContentTypeLookupBuilt;
    /// Scissoring for the light?
    bool mLightScissoring;
    /// User clip planes for light?
    bool mLightClipPlanes;
    /// Illumination stage?
    IlluminationStage mIlluminationStage;
    // User objects binding.
    UserObjectBindings  mUserObjectBindings;
    
    
    // Used to get scene blending flags from a blending type
    void _getBlendFlags(SceneBlendType type, out SceneBlendFactor source, out SceneBlendFactor dest)
    {
        final switch ( type )
        {
            case SceneBlendType.SBT_TRANSPARENT_ALPHA:
                source = SceneBlendFactor.SBF_SOURCE_ALPHA;
                dest = SceneBlendFactor.SBF_ONE_MINUS_SOURCE_ALPHA;
                return;
            case SceneBlendType.SBT_TRANSPARENT_COLOUR:
                source = SceneBlendFactor.SBF_SOURCE_COLOUR;
                dest = SceneBlendFactor.SBF_ONE_MINUS_SOURCE_COLOUR;
                return;
            case SceneBlendType.SBT_MODULATE:
                source = SceneBlendFactor.SBF_DEST_COLOUR;
                dest = SceneBlendFactor.SBF_ZERO;
                return;
            case SceneBlendType.SBT_ADD:
                source = SceneBlendFactor.SBF_ONE;
                dest = SceneBlendFactor.SBF_ONE;
                return;
            case SceneBlendType.SBT_REPLACE:
                source = SceneBlendFactor.SBF_ONE;
                dest = SceneBlendFactor.SBF_ZERO;
                return;
        }
        
        // Default to SBT_REPLACE
        
        source = SceneBlendFactor.SBF_ONE;
        dest = SceneBlendFactor.SBF_ZERO;
    }
    
public:
    //typedef set<Pass*>.type PassSet;
    //alias Set!Pass PassSet;
    alias Pass[] PassSet;
    
protected:
    /// List of Passes whose hashes need recalculating
    static PassSet msDirtyHashList;
    /// The place where passes go to die
    static PassSet msPassGraveyard;
    /// The Pass hash functor
    //static HashFunc* msHashFunc;
    //alias uint function(Pass p) HashFunc;
    static HashFunc msHashFunc;
public:    
    static void staticThis() //Suddenly cyclic ctor/dtor deps
    {
        msHashFunc = &MinTextureStateChangeHashFunc;
        msDirtyHashListMutex = new Mutex;
        msPassGraveyardMutex = new Mutex;
    }
    
public:
    static Mutex msDirtyHashListMutex;
    static Mutex msPassGraveyardMutex;
    Mutex mTexUnitChangeMutex;
    Mutex mGpuProgramChangeMutex;
    /// Default constructor
    this(Technique parent, ushort index)
    {
        mParent = parent;
        mIndex = index;
        mHash = 0;
        mHashDirtyQueued = false;
        mAmbient = ColourValue.White;
        mDiffuse = ColourValue.White;
        mSpecular = ColourValue.Black;
        mEmissive = ColourValue.Black;
        mShininess = 0;
        mTracking = TVC_NONE;
        mSourceBlendFactor = SceneBlendFactor.SBF_ONE;
        mDestBlendFactor = SceneBlendFactor.SBF_ZERO;
        mSourceBlendFactorAlpha = SceneBlendFactor.SBF_ONE;
        mDestBlendFactorAlpha = SceneBlendFactor.SBF_ZERO;
        mSeparateBlend = false;
        mBlendOperation = SceneBlendOperation.SBO_ADD;
        mAlphaBlendOperation = SceneBlendOperation.SBO_ADD;
        mSeparateBlendOperation = false;
        mDepthCheck = true;
        mDepthWrite = true;
        mDepthFunc = CompareFunction.CMPF_LESS_EQUAL;
        mDepthBiasConstant = 0.0f;
        mDepthBiasSlopeScale = 0.0f;
        mDepthBiasPerIteration = 0.0f;
        mColourWrite = true;
        mAlphaRejectFunc = CompareFunction.CMPF_ALWAYS_PASS;
        mAlphaRejectVal = 0;
        mAlphaToCoverageEnabled = false;
        mTransparentSorting = true;
        mTransparentSortingForced = false;
        mCullMode = CullingMode.CULL_CLOCKWISE;
        mManualCullMode = ManualCullingMode.MANUAL_CULL_BACK;
        mLightingEnabled = true;
        mMaxSimultaneousLights = OGRE_MAX_SIMULTANEOUS_LIGHTS;
        mStartLight = 0;
        mIteratePerLight = false;
        mLightsPerIteration = 1;
        mRunOnlyForOneLightType = false;
        mOnlyLightType = Light.LightTypes.LT_POINT;
        mLightMask = 0xFFFFFFFF;
        mShadeOptions = ShadeOptions.SO_GOURAUD;
        mPolygonMode = PolygonMode.PM_SOLID;
        mNormaliseNormals = false;
        mPolygonModeOverrideable = true;
        mFogOverride = false;
        mFogMode = FogMode.FOG_NONE;
        mFogColour = ColourValue.White;
        mFogStart = 0.0;
        mFogEnd = 1.0;
        mFogDensity = 0.001;
        /*mVertexProgramUsage = 0;
         mShadowCasterVertexProgramUsage = 0;
         mShadowCasterFragmentProgramUsage = 0;
         mShadowReceiverVertexProgramUsage = 0;
         mFragmentProgramUsage = 0;
         mShadowReceiverFragmentProgramUsage = 0;
         mGeometryProgramUsage = 0;
         mTesselationHullProgramUsage = 0;
         mTesselationDomainProgramUsage = 0;
         mComputeProgramUsage = 0;*/
        mQueuedForDeletion = false;
        mPassIterationCount = 1;
        mPointSize = 1.0f;
        mPointMinSize = 0.0f;
        mPointMaxSize = 0.0f;
        mPointSpritesEnabled = false;
        mPointAttenuationEnabled = false;
        mContentTypeLookupBuilt = false;
        mLightScissoring = false;
        mLightClipPlanes = false;
        mIlluminationStage = IlluminationStage.IS_UNKNOWN;
        
        mPointAttenuationCoeffs[0] = 1.0f;
        mPointAttenuationCoeffs[1] = mPointAttenuationCoeffs[2] = 0.0f;
        
        // default name to index
        mName = std.conv.to!string(mIndex);
        
        mTexUnitChangeMutex = new Mutex;
        mGpuProgramChangeMutex = new Mutex;
        
        // init the hash inline
        _recalculateHash();
    }
    /// Copy constructor
    this(Technique parent, ushort index, Pass oth )
    {
        mParent = parent;
        mIndex = index;
        /*mVertexProgramUsage = 0;
         mShadowCasterVertexProgramUsage = 0;
         mShadowCasterFragmentProgramUsage = 0;
         mShadowReceiverVertexProgramUsage = 0;
         mFragmentProgramUsage = 0;
         mShadowReceiverFragmentProgramUsage = 0;
         mGeometryProgramUsage = 0;
         mTesselationHullProgramUsage = 0;
         mTesselationDomainProgramUsage = 0;
         mComputeProgramUsage = 0;
         mQueuedForDeletion = false;*/
        mPassIterationCount = 1;
        
        //*this = oth;
        this.copyFrom(oth);
        mParent = parent;
        mIndex = index;
        mQueuedForDeletion = false;
        
        mTexUnitChangeMutex = new Mutex;
        mGpuProgramChangeMutex = new Mutex;
        
        // init the hash inline
        _recalculateHash();
        
    }
    /// Operator = overload
    //Pass& operator=(Pass& oth);
    void copyFrom(Pass oth)
    {
        mName = oth.mName;
        mHash = oth.mHash;
        mAmbient = oth.mAmbient;
        mDiffuse = oth.mDiffuse;
        mSpecular = oth.mSpecular;
        mEmissive = oth.mEmissive;
        mShininess = oth.mShininess;
        mTracking = oth.mTracking;
        
        // Copy fog parameters
        mFogOverride = oth.mFogOverride;
        mFogMode = oth.mFogMode;
        mFogColour = oth.mFogColour;
        mFogStart = oth.mFogStart;
        mFogEnd = oth.mFogEnd;
        mFogDensity = oth.mFogDensity;
        
        // Default blending (overwrite)
        mSourceBlendFactor = oth.mSourceBlendFactor;
        mDestBlendFactor = oth.mDestBlendFactor;
        mSourceBlendFactorAlpha = oth.mSourceBlendFactorAlpha;
        mDestBlendFactorAlpha = oth.mDestBlendFactorAlpha;
        mSeparateBlend = oth.mSeparateBlend;
        
        mBlendOperation = oth.mBlendOperation;
        mAlphaBlendOperation = oth.mAlphaBlendOperation;
        mSeparateBlendOperation = oth.mSeparateBlendOperation;
        
        mDepthCheck = oth.mDepthCheck;
        mDepthWrite = oth.mDepthWrite;
        mAlphaRejectFunc = oth.mAlphaRejectFunc;
        mAlphaRejectVal = oth.mAlphaRejectVal;
        mAlphaToCoverageEnabled = oth.mAlphaToCoverageEnabled;
        mTransparentSorting = oth.mTransparentSorting;
        mTransparentSortingForced = oth.mTransparentSortingForced;
        mColourWrite = oth.mColourWrite;
        mDepthFunc = oth.mDepthFunc;
        mDepthBiasConstant = oth.mDepthBiasConstant;
        mDepthBiasSlopeScale = oth.mDepthBiasSlopeScale;
        mDepthBiasPerIteration = oth.mDepthBiasPerIteration;
        mCullMode = oth.mCullMode;
        mManualCullMode = oth.mManualCullMode;
        mLightingEnabled = oth.mLightingEnabled;
        mMaxSimultaneousLights = oth.mMaxSimultaneousLights;
        mStartLight = oth.mStartLight;
        mIteratePerLight = oth.mIteratePerLight;
        mLightsPerIteration = oth.mLightsPerIteration;
        mRunOnlyForOneLightType = oth.mRunOnlyForOneLightType;
        mNormaliseNormals = oth.mNormaliseNormals;
        mOnlyLightType = oth.mOnlyLightType;
        mShadeOptions = oth.mShadeOptions;
        mPolygonMode = oth.mPolygonMode;
        mPolygonModeOverrideable = oth.mPolygonModeOverrideable;
        mPassIterationCount = oth.mPassIterationCount;
        mPointSize = oth.mPointSize;
        mPointMinSize = oth.mPointMinSize;
        mPointMaxSize = oth.mPointMaxSize;
        mPointSpritesEnabled = oth.mPointSpritesEnabled;
        mPointAttenuationEnabled = oth.mPointAttenuationEnabled;
        //memcpy(mPointAttenuationCoeffs, oth.mPointAttenuationCoeffs, sizeof(Real)*3);
        mPointAttenuationCoeffs[] = oth.mPointAttenuationCoeffs[0..$];
        mShadowContentTypeLookup = oth.mShadowContentTypeLookup;
        mContentTypeLookupBuilt = oth.mContentTypeLookupBuilt;
        mLightScissoring = oth.mLightScissoring;
        mLightClipPlanes = oth.mLightClipPlanes;
        mIlluminationStage = oth.mIlluminationStage;
        mLightMask = oth.mLightMask;
        
        destroy(mVertexProgramUsage);
        if (oth.mVertexProgramUsage)
        {
            mVertexProgramUsage = new GpuProgramUsage(oth.mVertexProgramUsage, this);
        }
        else
        {
            mVertexProgramUsage = null;
        }
        
        destroy(mShadowCasterVertexProgramUsage);
        if (oth.mShadowCasterVertexProgramUsage)
        {
            mShadowCasterVertexProgramUsage = new GpuProgramUsage(oth.mShadowCasterVertexProgramUsage, this);
        }
        else
        {
            mShadowCasterVertexProgramUsage = null;
        }
        
        destroy(mShadowCasterFragmentProgramUsage);
        if (oth.mShadowCasterFragmentProgramUsage)
        {
            mShadowCasterFragmentProgramUsage = new GpuProgramUsage(oth.mShadowCasterFragmentProgramUsage, this);
        }
        else
        {
            mShadowCasterFragmentProgramUsage = null;
        }
        
        destroy(mShadowReceiverVertexProgramUsage);
        if (oth.mShadowReceiverVertexProgramUsage)
        {
            mShadowReceiverVertexProgramUsage = new GpuProgramUsage(oth.mShadowReceiverVertexProgramUsage, this);
        }
        else
        {
            mShadowReceiverVertexProgramUsage = null;
        }
        
        destroy(mFragmentProgramUsage);
        if (oth.mFragmentProgramUsage)
        {
            mFragmentProgramUsage = new GpuProgramUsage(oth.mFragmentProgramUsage, this);
        }
        else
        {
            mFragmentProgramUsage = null;
        }
        
        destroy(mGeometryProgramUsage);
        if (oth.mGeometryProgramUsage)
        {
            mGeometryProgramUsage = new GpuProgramUsage(oth.mGeometryProgramUsage, this);
        }
        else
        {
            mGeometryProgramUsage = null;
        }
        
        destroy(mTesselationHullProgramUsage);
        if (oth.mTesselationHullProgramUsage)
        {
            mTesselationHullProgramUsage = new GpuProgramUsage(oth.mTesselationHullProgramUsage, this);
        }
        else
        {
            mTesselationHullProgramUsage = null;
        }
        
        destroy(mTesselationDomainProgramUsage);
        if (oth.mTesselationDomainProgramUsage)
        {
            mTesselationDomainProgramUsage = new GpuProgramUsage(oth.mTesselationDomainProgramUsage, this);
        }
        else
        {
            mTesselationDomainProgramUsage = null;
        }
        
        destroy(mComputeProgramUsage);
        if (oth.mComputeProgramUsage)
        {
            mComputeProgramUsage = new GpuProgramUsage(oth.mComputeProgramUsage, this);
        }
        else
        {
            mComputeProgramUsage = null;
        }
        
        destroy(mShadowReceiverFragmentProgramUsage);
        if (oth.mShadowReceiverFragmentProgramUsage)
        {
            mShadowReceiverFragmentProgramUsage = new GpuProgramUsage(oth.mShadowReceiverFragmentProgramUsage, this);
        }
        else
        {
            mShadowReceiverFragmentProgramUsage = null;
        }
        
        //TextureUnitStates.const_iterator i, iend;
        
        // Clear texture units but doesn't notify need recompilation in the case
        // we are cloning, The parent material will take care of this.
        //
        foreach (i; mTextureUnitStates)
        {
            destroy(i);
        }
        
        mTextureUnitStates.clear();
        
        // Copy texture units
        //iend = oth.mTextureUnitStates.end();
        foreach (i; oth.mTextureUnitStates)
        {
            auto t = new TextureUnitState(this, i);
            mTextureUnitStates.insert(t);
        }
        
        _dirtyHash();
    }
    
    ~this()
    {
        destroy(mVertexProgramUsage);
        destroy(mFragmentProgramUsage);
        destroy(mTesselationHullProgramUsage);
        destroy(mTesselationDomainProgramUsage);
        destroy(mGeometryProgramUsage);
        destroy(mComputeProgramUsage);
        destroy(mShadowCasterVertexProgramUsage);
        destroy(mShadowCasterFragmentProgramUsage);
        destroy(mShadowReceiverVertexProgramUsage);
        destroy(mShadowReceiverFragmentProgramUsage);
    }
    
    /// Returns true if this pass is programmable i.e. includes either a vertex or fragment program.
    bool isProgrammable(){ return mVertexProgramUsage || mFragmentProgramUsage || mGeometryProgramUsage ||
        mTesselationHullProgramUsage || mTesselationDomainProgramUsage || mComputeProgramUsage; }
    
    /// Returns true if this pass uses a programmable vertex pipeline
    bool hasVertexProgram(){ return mVertexProgramUsage !is null; }
    /// Returns true if this pass uses a programmable fragment pipeline
    bool hasFragmentProgram(){ return mFragmentProgramUsage !is null; }
    /// Returns true if this pass uses a programmable geometry pipeline
    bool hasGeometryProgram(){ return mGeometryProgramUsage !is null; }
    /// Returns true if this pass uses a programmable tesselation control pipeline
    bool hasTesselationHullProgram(){ return mTesselationHullProgramUsage !is null; }
    /// Returns true if this pass uses a programmable tesselation control pipeline
    bool hasTesselationDomainProgram(){ return mTesselationDomainProgramUsage !is null; }
    /// Returns true if this pass uses a programmable compute pipeline
    bool hasComputeProgram(){ return mComputeProgramUsage !is null; }
    /// Returns true if this pass uses a shadow caster vertex program
    bool hasShadowCasterVertexProgram(){ return mShadowCasterVertexProgramUsage !is null; }
    /// Returns true if this pass uses a shadow caster fragment program
    bool hasShadowCasterFragmentProgram(){ return mShadowCasterFragmentProgramUsage !is null; }
    /// Returns true if this pass uses a shadow receiver vertex program
    bool hasShadowReceiverVertexProgram(){ return mShadowReceiverVertexProgramUsage !is null; }
    /// Returns true if this pass uses a shadow receiver fragment program
    bool hasShadowReceiverFragmentProgram(){ return mShadowReceiverFragmentProgramUsage !is null; }
    
    
    /// Gets the index of this Pass in the parent Technique
    ushort getIndex(){ return mIndex; }
    
    size_t calculateSize() //const
    {
        size_t memSize = 0;
        
        // Tally up TU states
        foreach (i; mTextureUnitStates)
        {
            memSize += i.calculateSize();
        }
        if(mVertexProgramUsage)
            memSize += mVertexProgramUsage.calculateSize();
        if(mShadowCasterVertexProgramUsage)
            memSize += mShadowCasterVertexProgramUsage.calculateSize();
        if(mShadowCasterFragmentProgramUsage)
            memSize += mShadowCasterFragmentProgramUsage.calculateSize();
        if(mShadowReceiverVertexProgramUsage)
            memSize += mShadowReceiverVertexProgramUsage.calculateSize();
        if(mFragmentProgramUsage)
            memSize += mFragmentProgramUsage.calculateSize();
        if(mShadowReceiverFragmentProgramUsage)
            memSize += mShadowReceiverFragmentProgramUsage.calculateSize();
        if(mGeometryProgramUsage)
            memSize += mGeometryProgramUsage.calculateSize();
        if(mTesselationHullProgramUsage)
            memSize += mTesselationHullProgramUsage.calculateSize();
        if(mTesselationDomainProgramUsage)
            memSize += mTesselationDomainProgramUsage.calculateSize();
        if(mComputeProgramUsage)
            memSize += mComputeProgramUsage.calculateSize();
        return memSize;
    }
    
    /* Set the name of the pass
     @remarks
     The name of the pass is optional.  Its useful in material scripts where a material could inherit
     from another material and only want to modify a particular pass.
     */
    void setName(string name)
    {
        mName = name;
    }
    /// get the name of the pass
    string getName(){ return mName; }
    
    /** Sets the ambient colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much ambient light (directionless global light) is reflected. The default is full white, meaning
     objects are completely globally illuminated. Reduce this if you want to see diffuse or specular light
     effects, or change the blend of colours to make the object have a base colour other than white.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setAmbient(Real red, Real green, Real blue)
    {
        mAmbient.r = red;
        mAmbient.g = green;
        mAmbient.b = blue;
        
    }
    
    /** Sets the ambient colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much ambient light (directionless global light) is reflected. The default is full white, meaning
     objects are completely globally illuminated. Reduce this if you want to see diffuse or specular light
     effects, or change the blend of colours to make the object have a base colour other than white.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    
    void setAmbient(ColourValue ambient)
    {
        mAmbient = ambient;
    }
    
    /** Sets the diffuse colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much diffuse light (light from instances of the Light class in the scene) is reflected. The default
     is full white, meaning objects reflect the maximum white light they can from Light objects.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setDiffuse(Real red, Real green, Real blue, Real alpha)
    {
        mDiffuse.r = red;
        mDiffuse.g = green;
        mDiffuse.b = blue;
        mDiffuse.a = alpha;
    }
    
    /** Sets the diffuse colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much diffuse light (light from instances of the Light class in the scene) is reflected. The default
     is full white, meaning objects reflect the maximum white light they can from Light objects.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setDiffuse(ColourValue diffuse)
    {
        mDiffuse = diffuse;
    }
    
    /** Sets the specular colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much specular light (highlights from instances of the Light class in the scene) is reflected.
     The default is to reflect no specular light.
     @note
     The size of the specular highlights is determined by the separate 'shininess' property.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setSpecular(Real red, Real green, Real blue, Real alpha)
    {
        mSpecular.r = red;
        mSpecular.g = green;
        mSpecular.b = blue;
        mSpecular.a = alpha;
    }
    
    /** Sets the specular colour reflectance properties of this pass.
     @remarks
     The base colour of a pass is determined by how much red, green and blue light is reflects
     (provided texture layer #0 has a blend mode other than LBO_REPLACE). This property determines how
     much specular light (highlights from instances of the Light class in the scene) is reflected.
     The default is to reflect no specular light.
     @note
     The size of the specular highlights is determined by the separate 'shininess' property.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setSpecular(ColourValue specular)
    {
        mSpecular = specular;
    }
    
    /** Sets the shininess of the pass, affecting the size of specular highlights.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setShininess(Real val)
    {
        mShininess = val;
    }
    
    /** Sets the amount of self-illumination an object has.
     @remarks
     If an object is self-illuminating, it does not need external sources to light it, ambient or
     otherwise. It's like the object has it's own personal ambient light. This property is rarely useful since
     you can already specify per-pass ambient light, but is here for completeness.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setSelfIllumination(Real red, Real green, Real blue)
    {
        mEmissive.r = red;
        mEmissive.g = green;
        mEmissive.b = blue;
        
    }
    
    /** Sets the amount of self-illumination an object has.
     @see
     setSelfIllumination
     */
    void setEmissive(Real red, Real green, Real blue)
    {
        setSelfIllumination(red, green, blue);
    }
    
    /** Sets the amount of self-illumination an object has.
     @remarks
     If an object is self-illuminating, it does not need external sources to light it, ambient or
     otherwise. It's like the object has it's own personal ambient light. This property is rarely useful since
     you can already specify per-pass ambient light, but is here for completeness.
     @note
     This setting has no effect if dynamic lighting is disabled (see Pass.setLightingEnabled),
     or if this is a programmable pass.
     */
    void setSelfIllumination(ColourValue selfIllum)
    {
        mEmissive = selfIllum;
    }
    
    /** Sets the amount of self-illumination an object has.
     @see
     setSelfIllumination
     */
    void setEmissive(ColourValue emissive)
    {
        setSelfIllumination(emissive);
    }
    
    /** Sets which material properties follow the vertex colour
     */
    void setVertexColourTracking(TrackVertexColour tracking)
    {
        mTracking = tracking;
    }
    
    /** Gets the point size of the pass.
     @remarks
     This property determines what point size is used to render a point
     list.
     */
    Real getPointSize()
    {
        return mPointSize;
    }
    
    /** Sets the point size of this pass.
     @remarks
     This setting allows you to change the size of points when rendering
     a point list, or a list of point sprites. The interpretation of this
     command depends on the Pass.setPointSizeAttenuation option - if it
     is off (the default), the point size is in screen pixels, if it is on,
     it expressed as normalised screen coordinates (1.0 is the height of
     the screen) when the point is at the origin.
     @note
     Some drivers have an upper limit on the size of points they support
     - this can even vary between APIs on the same card! Don't rely on
     point sizes that cause the point sprites to get very large on screen,
     since they may get clamped on some cards. Upper sizes can range from
     64 to 256 pixels.
     */
    void setPointSize(Real ps)
    {
        mPointSize = ps;
    }
    
    /** Sets whether or not rendering points using OT_POINT_LIST will
     render point sprites (textured quads) or plain points (dots).
     @param enabled True enables point sprites, false returns to normal
     point rendering.
     */
    void setPointSpritesEnabled(bool enabled)
    {
        mPointSpritesEnabled = enabled;
    }
    
    /** Returns whether point sprites are enabled when rendering a
     point list.
     */
    bool getPointSpritesEnabled()
    {
        return mPointSpritesEnabled;
    }
    
    /** Sets how points are attenuated with distance.
     @remarks
     When performing point rendering or point sprite rendering,
     point size can be attenuated with distance. The equation for
     doing this is attenuation = 1 / (constant + linear * dist + quadratic * d^2).
     @par
     For example, to disable distance attenuation (constant screensize)
     you would setant to 1, and linear and quadratic to 0. A
     standard perspective attenuation would be 0, 1, 0 respectively.
     @note
     The resulting size is clamped to the minimum and maximum point
     size.
     @param enabled Whether point attenuation is enabled
     @param constant, linear, quadratic Parameters to the attenuation
     function defined above
     */
    void setPointAttenuation(bool enabled,
                             Real constant = 0.0f, Real linear = 1.0f, Real quadratic = 0.0f)
    {
        mPointAttenuationEnabled = enabled;
        mPointAttenuationCoeffs[0] = constant;
        mPointAttenuationCoeffs[1] = linear;
        mPointAttenuationCoeffs[2] = quadratic;
    }
    
    /** Returns whether points are attenuated with distance. */
    bool isPointAttenuationEnabled()
    {
        return mPointAttenuationEnabled;
    }
    
    /** Returns the constant coefficient of point attenuation. */
    Real getPointAttenuationConstant()
    {
        return mPointAttenuationCoeffs[0];
    }
    /** Returns the linear coefficient of point attenuation. */
    Real getPointAttenuationLinear()
    {
        return mPointAttenuationCoeffs[1];
    }
    /** Returns the quadratic coefficient of point attenuation. */
    Real getPointAttenuationQuadratic()
    {
        return mPointAttenuationCoeffs[2];
    }
    
    /** Set the minimum point size, when point attenuation is in use. */
    void setPointMinSize(Real min)
    {
        mPointMinSize = min;
    }
    /** Get the minimum point size, when point attenuation is in use. */
    Real getPointMinSize()
    {
        return mPointMinSize;
    }
    /** Set the maximum point size, when point attenuation is in use.
     @remarks Setting this to 0 indicates the max size supported by the card.
     */
    void setPointMaxSize(Real max)
    {
        mPointMaxSize = max;
    }
    /** Get the maximum point size, when point attenuation is in use.
     @remarks 0 indicates the max size supported by the card.
     */
    Real getPointMaxSize()
    {
        return mPointMaxSize;
    }
    
    /** Gets the ambient colour reflectance of the pass.
     */
    ColourValue getAmbient()
    {
        return mAmbient;
    }
    
    /** Gets the diffuse colour reflectance of the pass.
     */
    ColourValue getDiffuse()
    {
        return mDiffuse;
    }
    
    /** Gets the specular colour reflectance of the pass.
     */
    ColourValue getSpecular()
    {
        return mSpecular;
    }
    
    /** Gets the self illumination colour of the pass.
     */
    ColourValue getSelfIllumination()
    {
        return mEmissive;
    }
    
    /** Gets the self illumination colour of the pass.
     @see
     getSelfIllumination
     */
    ColourValue getEmissive()
    {
        return getSelfIllumination();
    }
    
    /** Gets the 'shininess' property of the pass (affects specular highlights).
     */
    Real getShininess()
    {
        return mShininess;
    }
    
    /** Gets which material properties follow the vertex colour
     */
    TrackVertexColour getVertexColourTracking()
    {
        return mTracking;
    }
    
    /** Inserts a new TextureUnitState object into the Pass.
     @remarks
     This unit is is added on top of all previous units.
     */
    TextureUnitState createTextureUnitState()
    {
        auto t = new TextureUnitState(this);
        addTextureUnitState(t);
        mContentTypeLookupBuilt = false;
        return t;
    }
    /** Inserts a new TextureUnitState object into the Pass.
     @remarks
     This unit is is added on top of all previous units.
     @param textureName
     The basic name of the texture e.g. brickwall.jpg, stonefloor.png
     @param texCoordSet
     The index of the texture coordinate set to use.
     @note
     Applies to both fixed-function and programmable passes.
     */
    TextureUnitState createTextureUnitState( string textureName, ushort texCoordSet = 0)
    {
        auto t = new TextureUnitState(this);
        t.setTextureName(textureName);
        t.setTextureCoordSet(texCoordSet);
        addTextureUnitState(t);
        mContentTypeLookupBuilt = false;
        return t;
    }
    /** Adds the passed in TextureUnitState, to the existing Pass.
     @param
     state The Texture Unit State to be attached to this pass.  It must not be attached to another pass.
     @note
     Throws an exception if the TextureUnitState is attached to another Pass.*/
    void addTextureUnitState(TextureUnitState state)
    {
        synchronized(mTexUnitChangeMutex)
        {
            assert(state , "state is 0 in Pass.addTextureUnitState()");
            if (state)
            {
                // only attach TUS to pass if TUS does not belong to another pass
                if ((state.getParent() is null) || (state.getParent() == this))
                {
                    mTextureUnitStates.insert(state);
                    // Notify state
                    state._notifyParent(this);
                    // if texture unit state name is empty then give it a default name based on its index
                    if (state.getName() is null)
                    {
                        // its the last entry in the container so its index is size - 1
                        size_t idx = mTextureUnitStates.length - 1;
                        state.setName( std.conv.to!string(idx) );
                        /** since the name was never set and a default one has been made, clear the alias name
                         so that when the texture unit name is set by the user, the alias name will be set to
                         that name
                         */
                        state.setTextureNameAlias("");
                    }
                    // Needs recompilation
                    mParent._notifyNeedsRecompile();
                    _dirtyHash();
                }
                else
                {
                    throw new InvalidParamsError("TextureUnitState already attached to another pass",
                                                 "Pass:addTextureUnitState");
                    
                }
                mContentTypeLookupBuilt = false;
            }
        }
    }
    /** Retrieves a pointer to a texture unit state so it may be modified.
     */
    TextureUnitState getTextureUnitState(ushort index)
    {
        synchronized(mTexUnitChangeMutex)
        {
            //assert (index < mTextureUnitStates.length && "Index out of bounds");
            return mTextureUnitStates[index];
        }
    }

    const(TextureUnitState) getTextureUnitState(ushort index) const
    {
        synchronized(mTexUnitChangeMutex)
        {
            //assert (index < mTextureUnitStates.length && "Index out of bounds");
            return mTextureUnitStates[index];
        }
    }
    /** Retrieves the Texture Unit State matching name.
     Returns 0 if name match is not found.
     */
    TextureUnitState getTextureUnitState(string name)
    {
        synchronized(mTexUnitChangeMutex)
        {
            TextureUnitState foundTUS = null;
            
            // iterate through TUS Container to find a match
            foreach(i; mTextureUnitStates)
            {
                if ( i.getName() == name )
                {
                    foundTUS = i;
                    break;
                    //return i;
                }
            }
            
            return foundTUS;
        }
    }

    /** Retrieves apointer to a texture unit state.
     */
    //TextureUnitState getTextureUnitState(ushort index);
    
    /** Retrieves the Texture Unit State matching name.
     Returns 0 if name match is not found.
     */
    //TextureUnitState* getTextureUnitState(string name);
    
    /**  Retrieve the index of the Texture Unit State in the pass.
     @param
     state The Texture Unit State this is attached to this pass.
     @note
     Throws an exception if the state is not attached to the pass.
     */
    ushort getTextureUnitStateIndex(TextureUnitState state)
    {
        synchronized(mTexUnitChangeMutex)
        {
            assert(state && "state is 0 in Pass.getTextureUnitStateIndex()");
            
            // only find index for state attached to this pass
            if (state.getParent() == this)
            {
                long i = std.algorithm.countUntil(mTextureUnitStates, state);
                assert(i != -1 , "state is supposed to attached to this pass");
                return cast(ushort)i;
            }
            else
            {
                throw new InvalidParamsError("TextureUnitState is not attached to this pass",
                                             "Pass:getTextureUnitStateIndex");
            }
        }
    }
    
    //typedef VectorIterator<TextureUnitStates> TextureUnitStateIterator;
    /** Get an iterator over the TextureUnitStates contained in this Pass. */
    //TextureUnitStateIterator getTextureUnitStateIterator();
    TextureUnitStates getTextureUnitStates()
    {
        return mTextureUnitStates;
    }

    //typedef ConstVectorIterator<TextureUnitStates> ConstTextureUnitStateIterator;
    /** Get an iterator over the TextureUnitStates contained in this Pass. */
    //ConstTextureUnitStateIterator getTextureUnitStateIterator();
    
    /** Removes the indexed texture unit state from this pass.
     @remarks
     Note that removing a texture which is not the topmost will have a larger performance impact.
     */
    void removeTextureUnitState(ushort index)
    {
        synchronized(mTexUnitChangeMutex)
        {
            //assert (index < mTextureUnitStates.length , "Index out of bounds");
            
            //TextureUnitStates.iterator i = mTextureUnitStates.begin() + index;
            auto i = mTextureUnitStates[index];
            mTextureUnitStates.removeFromArrayIdx(index);
            destroy(i);
            
            if (!mQueuedForDeletion)
            {
                // Needs recompilation
                mParent._notifyNeedsRecompile();
            }
            _dirtyHash();
            mContentTypeLookupBuilt = false;
        }
    }
    
    /** Removes all texture unit settings.
     */
    void removeAllTextureUnitStates()
    {
        synchronized(mTexUnitChangeMutex)
        {
            foreach (i; mTextureUnitStates)
            {
                destroy(i);
            }
            mTextureUnitStates.clear();
            if (!mQueuedForDeletion)
            {
                // Needs recompilation
                mParent._notifyNeedsRecompile();
            }
            _dirtyHash();
            mContentTypeLookupBuilt = false;
        }
    }
    
    /** Returns the number of texture unit settings.
     */
    ushort getNumTextureUnitStates()
    {
        return cast(ushort)(mTextureUnitStates.length);
    }
    
    /** Sets the kind of blending this pass has with the existing contents of the scene.
     @remarks
     Whereas the texture blending operations seen in the TextureUnitState class are concerned with
     blending between texture layers, this blending is about combining the output of the Pass
     as a whole with the existing contents of the rendering target. This blending Therefore allows
     object transparency and other special effects. If all passes in a technique have a scene
     blend, then the whole technique is considered to be transparent.
     @par
     This method allows you to select one of a number of predefined blending types. If you require more
     control than this, use the alternative version of this method which allows you to specify source and
     destination blend factors.
     @note
     This method is applicable for both the fixed-function and programmable pipelines.
     @param
     sbt One of the predefined SceneBlendType blending types
     */
    void setSceneBlending(SceneBlendType sbt )
    {
        // Convert type into blend factors
        
        SceneBlendFactor source;
        SceneBlendFactor dest;
        _getBlendFlags(sbt, source, dest);
        
        // Set blend factors
        
        setSceneBlending(source, dest);
    }
    
    /** Sets the kind of blending this pass has with the existing contents of the scene, separately for color and alpha channels
     @remarks
     Whereas the texture blending operations seen in the TextureUnitState class are concerned with
     blending between texture layers, this blending is about combining the output of the Pass
     as a whole with the existing contents of the rendering target. This blending Therefore allows
     object transparency and other special effects. If all passes in a technique have a scene
     blend, then the whole technique is considered to be transparent.
     @par
     This method allows you to select one of a number of predefined blending types. If you require more
     control than this, use the alternative version of this method which allows you to specify source and
     destination blend factors.
     @note
     This method is applicable for both the fixed-function and programmable pipelines.
     @param
     sbt One of the predefined SceneBlendType blending types for the color channel
     @param
     sbta One of the predefined SceneBlendType blending types for the alpha channel
     */
    void setSeparateSceneBlending(SceneBlendType sbt,SceneBlendType sbta )
    {
        // Convert types into blend factors
        
        SceneBlendFactor source;
        SceneBlendFactor dest;
        _getBlendFlags(sbt, source, dest);
        
        SceneBlendFactor sourceAlpha;
        SceneBlendFactor destAlpha;
        _getBlendFlags(sbta, sourceAlpha, destAlpha);
        
        // Set blend factors
        
        setSeparateSceneBlending(source, dest, sourceAlpha, destAlpha);
    }
    
    /** Allows very fine control of blending this Pass with the existing contents of the scene.
     @remarks
     Whereas the texture blending operations seen in the TextureUnitState class are concerned with
     blending between texture layers, this blending is about combining the output of the material
     as a whole with the existing contents of the rendering target. This blending Therefore allows
     object transparency and other special effects.
     @par
     This version of the method allows complete control over the blending operation, by specifying the
     source and destination blending factors. The result of the blending operation is:
     <span align="center">
     final = (texture * sourceFactor) + (pixel * destFactor)
     </span>
     @par
     Each of the factors is specified as one of a number of options, as specified in the SceneBlendFactor
     enumerated type.
     @param
     sourceFactor The source factor in the above calculation, i.e. multiplied by the texture colour components.
     @param
     destFactor The destination factor in the above calculation, i.e. multiplied by the pixel colour components.
     @note
     This method is applicable for both the fixed-function and programmable pipelines.
     */
    void setSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor)
    {
        mSourceBlendFactor = sourceFactor;
        mDestBlendFactor = destFactor;
        
        mSeparateBlend = false;
    }
    
    /** Allows very fine control of blending this Pass with the existing contents of the scene.
     @remarks
     Whereas the texture blending operations seen in the TextureUnitState class are concerned with
     blending between texture layers, this blending is about combining the output of the material
     as a whole with the existing contents of the rendering target. This blending Therefore allows
     object transparency and other special effects.
     @par
     This version of the method allows complete control over the blending operation, by specifying the
     source and destination blending factors. The result of the blending operation is:
     <span align="center">
     final = (texture * sourceFactor) + (pixel * destFactor)
     </span>
     @par
     Each of the factors is specified as one of a number of options, as specified in the SceneBlendFactor
     enumerated type.
     @param
     sourceFactor The source factor in the above calculation, i.e. multiplied by the texture colour components.
     @param
     destFactor The destination factor in the above calculation, i.e. multiplied by the pixel colour components.
     @param
     sourceFactorAlpha The alpha source factor in the above calculation, i.e. multiplied by the texture alpha component.
     @param
     destFactorAlpha The alpha destination factor in the above calculation, i.e. multiplied by the pixel alpha component.
     @note
     This method is applicable for both the fixed-function and programmable pipelines.
     */
    void setSeparateSceneBlending(SceneBlendFactor sourceFactor,SceneBlendFactor destFactor,SceneBlendFactor sourceFactorAlpha,SceneBlendFactor destFactorAlpha )
    {
        mSourceBlendFactor = sourceFactor;
        mDestBlendFactor = destFactor;
        mSourceBlendFactorAlpha = sourceFactorAlpha;
        mDestBlendFactorAlpha = destFactorAlpha;
        
        mSeparateBlend = true;
    }
    
    /** Return true if this pass uses separate scene blending */
    bool hasSeparateSceneBlending()
    {
        return mSeparateBlend;
    }
    
    /** Retrieves the source blending factor for the material (as set using Materiall.setSceneBlending).
     */
    SceneBlendFactor getSourceBlendFactor()
    {
        return mSourceBlendFactor;
    }
    
    /** Retrieves the destination blending factor for the material (as set using Materiall.setSceneBlending).
     */
    SceneBlendFactor getDestBlendFactor()
    {
        return mDestBlendFactor;
    }
    
    /** Retrieves the alpha source blending factor for the material (as set using Materiall.setSeparateSceneBlending).
     */
    SceneBlendFactor getSourceBlendFactorAlpha()
    {
        return mSourceBlendFactorAlpha;
    }
    
    /** Retrieves the alpha destination blending factor for the material (as set using Materiall.setSeparateSceneBlending).
     */
    SceneBlendFactor getDestBlendFactorAlpha()
    {
        return mDestBlendFactorAlpha;
    }
    
    /** Sets the specific operation used to blend source and destination pixels together.
     @remarks 
     By default this operation is +, which creates this equation
     <span align="center">
     final = (texture * sourceFactor) + (pixel * destFactor)
     </span>
     By setting this to something other than SBO_ADD you can change the operation to achieve
     a different effect.
     @param op The blending operation mode to use for this pass
     */
    void setSceneBlendingOperation(SceneBlendOperation op)
    {
        mBlendOperation = op;
        mSeparateBlendOperation = false;
    }
    
    /** Sets the specific operation used to blend source and destination pixels together.
     @remarks 
     By default this operation is +, which creates this equation
     <span align="center">
     final = (texture * sourceFactor) + (pixel * destFactor)
     </span>
     By setting this to something other than SBO_ADD you can change the operation to achieve
     a different effect.
     This function allows more control over blending since it allows you to select different blending
     modes for the color and alpha channels
     @param op The blending operation mode to use for color channels in this pass
     @param alphaOp The blending operation mode to use for alpha channels in this pass
     */
    void setSeparateSceneBlendingOperation(SceneBlendOperation op, SceneBlendOperation alphaOp)
    {
        mBlendOperation = op;
        mAlphaBlendOperation = alphaOp;
        mSeparateBlendOperation = true;
    }
    
    /** Returns true if this pass uses separate scene blending operations. */
    bool hasSeparateSceneBlendingOperations()
    {
        return mSeparateBlendOperation;
    }
    
    /** Returns the current blending operation */
    SceneBlendOperation getSceneBlendingOperation()
    {
        return mBlendOperation;
    }
    
    /** Returns the current alpha blending operation */
    SceneBlendOperation getSceneBlendingOperationAlpha()
    {
        return mAlphaBlendOperation;
    }
    
    /** Returns true if this pass has some element of transparency. */
    bool isTransparent()
    {
        // Transparent if any of the destination colour is taken into account
        if (mDestBlendFactor == SceneBlendFactor.SBF_ZERO &&
            mSourceBlendFactor != SceneBlendFactor.SBF_DEST_COLOUR &&
            mSourceBlendFactor != SceneBlendFactor.SBF_ONE_MINUS_DEST_COLOUR &&
            mSourceBlendFactor != SceneBlendFactor.SBF_DEST_ALPHA &&
            mSourceBlendFactor != SceneBlendFactor.SBF_ONE_MINUS_DEST_ALPHA)
        {
            return false;
        }
        else
        {
            return true;
        }
    }
    
    /** Sets whether or not this pass renders with depth-buffer checking on or not.
     @remarks
     If depth-buffer checking is on, whenever a pixel is about to be written to the frame buffer
     the depth buffer is checked to see if the pixel is in front of all other pixels written at that
     point. If not, the pixel is not written.
     @par
     If depth checking is off, pixels are written no matter what has been rendered before.
     Also see setDepthFunction for more advanced depth check configuration.
     @see
     setDepthFunction
     */
    void setDepthCheckEnabled(bool enabled)
    {
        mDepthCheck = enabled;
    }
    
    /** Returns whether or not this pass renders with depth-buffer checking on or not.
     @see
     setDepthCheckEnabled
     */
    bool getDepthCheckEnabled()
    {
        return mDepthCheck;
    }
    
    /** Sets whether or not this pass renders with depth-buffer writing on or not.
     @remarks
     If depth-buffer writing is on, whenever a pixel is written to the frame buffer
     the depth buffer is updated with the depth value of that new pixel, thus affecting future
     rendering operations if future pixels are behind this one.
     @par
     If depth writing is off, pixels are written without updating the depth buffer Depth writing should
     normally be on but can be turned off when rendering static backgrounds or when rendering a collection
     of transparent objects at the end of a scene so that they overlap each other correctly.
     */
    void setDepthWriteEnabled(bool enabled)
    {
        mDepthWrite = enabled;
    }
    
    /** Returns whether or not this pass renders with depth-buffer writing on or not.
     @see
     setDepthWriteEnabled
     */
    bool getDepthWriteEnabled()
    {
        return mDepthWrite;
    }
    
    /** Sets the function used to compare depth values when depth checking is on.
     @remarks
     If depth checking is enabled (see setDepthCheckEnabled) a comparison occurs between the depth
     value of the pixel to be written and the current contents of the buffer. This comparison is
     normally CMPF_LESS_EQUAL, i.e. the pixel is written if it is closer (or at the same distance)
     than the current contents. If you wish you can change this comparison using this method.
     */
    void setDepthFunction( CompareFunction func )
    {
        mDepthFunc = func;
    }
    /** Returns the function used to compare depth values when depth checking is on.
     @see
     setDepthFunction
     */
    CompareFunction getDepthFunction()
    {
        return mDepthFunc;
    }
    
    /** Sets whether or not colour buffer writing is enabled for this Pass.
     @remarks
     For some effects, you might wish to turn off the colour write operation
     when rendering geometry; this means that only the depth buffer will be
     updated (provided you have depth buffer writing enabled, which you
     probably will do, although you may wish to only update the stencil
     buffer for example - stencil buffer state is managed at the RenderSystem
     level only, not the Material since you are likely to want to manage it
     at a higher level).
     */
    void setColourWriteEnabled(bool enabled)
    {
        mColourWrite = enabled;
    }
    /** Determines if colour buffer writing is enabled for this pass. */
    bool getColourWriteEnabled()
    {
        return mColourWrite;
    }
    
    /** Sets the culling mode for this pass  based on the 'vertex winding'.
     @remarks
     A typical way for the rendering engine to cull triangles is based on the 'vertex winding' of
     triangles. Vertex winding refers to the direction in which the vertices are passed or indexed
     to in the rendering operation as viewed from the camera, and will wither be clockwise or
     anticlockwise (that's 'counterclockwise' for you Americans out there ;) The default is
     CULL_CLOCKWISE i.e. that only triangles whose vertices are passed/indexed in anticlockwise order
     are rendered - this is a common approach and is used in 3D studio models for example. You can
     alter this culling mode if you wish but it is not advised unless you know what you are doing.
     @par
     You may wish to use the CULL_NONE option for mesh data that you cull yourself where the vertex
     winding is uncertain.
     */
    void setCullingMode( CullingMode mode )
    {
        mCullMode = mode;
    }
    
    /** Returns the culling mode for geometry rendered with this pass. See setCullingMode for more information.
     */
    CullingMode getCullingMode()
    {
        return mCullMode;
    }
    
    /** Sets the manual culling mode, performed by CPU rather than hardware.
     @remarks
     In some situations you want to use manual culling of triangles rather than sending the
     triangles to the hardware and letting it cull them. This setting only takes effect on SceneManager's
     that use it (since it is best used on large groups of planar world geometry rather than on movable
     geometry since this would be expensive), but if used can cull geometry before it is sent to the
     hardware.
     @note
     The default for this setting is MANUAL_CULL_BACK.
     @param
     mode The mode to use - see enum ManualCullingMode for details

     */
    void setManualCullingMode( ManualCullingMode mode )
    {
        mManualCullMode = mode;
    }
    
    /** Retrieves the manual culling mode for this pass
     @see
     setManualCullingMode
     */
    ManualCullingMode getManualCullingMode()
    {
        return mManualCullMode;
    }
    
    /** Sets whether or not dynamic lighting is enabled.
     @param
     enabled
     If true, dynamic lighting is performed on geometry with normals supplied, geometry without
     normals will not be displayed.
     @par
     If false, no lighting is applied and all geometry will be full brightness.
     */
    void setLightingEnabled(bool enabled)
    {
        mLightingEnabled = enabled;
    }
    
    /** Returns whether or not dynamic lighting is enabled.
     */
    bool getLightingEnabled()
    {
        return mLightingEnabled;
    }
    
    /** Sets the maximum number of lights to be used by this pass.
     @remarks
     During rendering, if lighting is enabled (or if the pass uses an automatic
     program parameter based on a light) the engine will request the nearest lights
     to the object being rendered in order to work out which ones to use. This
     parameter sets the limit on the number of lights which should apply to objects
     rendered with this pass.
     */
    void setMaxSimultaneousLights(ushort maxLights)
    {
        mMaxSimultaneousLights = maxLights;
    }
    /** Gets the maximum number of lights to be used by this pass. */
    ushort getMaxSimultaneousLights()
    {
        return mMaxSimultaneousLights;
    }
    
    /** Sets the light index that this pass will start at in the light list.
     @remarks
     Normally the lights passed to a pass will start from the beginning
     of the light list for this object. This option allows you to make this
     pass start from a higher light index, for example if one of your earlier
     passes could deal with lights 0-3, and this pass dealt with lights 4+. 
     This option also has an interaction with pass iteration, in that
     if you choose to iterate this pass per light too, the iteration will
     only begin from light 4.
     */
    void setStartLight(ushort startLight)
    {
        mStartLight = startLight;
    }
    /** Gets the light index that this pass will start at in the light list. */
    ushort getStartLight()
    {
        return mStartLight;
    }
    
    /** Sets the light mask which can be matched to specific light flags to be handled by this pass */
    void setLightMask(uint mask)
    {
        mLightMask = mask;
    }
    /** Gets the light mask controlling which lights are used for this pass */
    uint getLightMask()
    {
        return mLightMask;
    }
    
    /** Sets the type of light shading required
     @note
     The default shading method is Gouraud shading.
     */
    void setShadingMode( ShadeOptions mode )
    {
        mShadeOptions = mode;
    }
    
    /** Returns the type of light shading to be used.
     */
    ShadeOptions getShadingMode()
    {
        return mShadeOptions;
    }
    
    /** Sets the type of polygon rendering required
     @note
     The default shading method is Solid
     */
    void setPolygonMode( PolygonMode mode )
    {
        mPolygonMode = mode;
    }
    
    /** Returns the type of light shading to be used.
     */
    PolygonMode getPolygonMode()
    {
        return mPolygonMode;
    }
    
    /** Sets whether this pass's chosen detail level can be
     overridden (downgraded) by the camera setting. 
     @param override true means that a lower camera detail will override this
     pass's detail level, false means it won't (default true).
     */
    void setPolygonModeOverrideable(bool _override)
    {
        mPolygonModeOverrideable = _override;
    }
    
    /** Gets whether this renderable's chosen detail level can be
     overridden (downgraded) by the camera setting. 
     */
    bool getPolygonModeOverrideable()
    {
        return mPolygonModeOverrideable;
    }
    /** Sets the fogging mode applied to this pass.
     @remarks
     Fogging is an effect that is applied as polys are rendered. Sometimes, you want
     fog to be applied to an entire scene. Other times, you want it to be applied to a few
     polygons only. This pass-level specification of fog parameters lets you easily manage
     both.
     @par
     The SceneManager class also has a setFog method which applies scene-level fog. This method
     lets you change the fog behaviour for this pass compared to the standard scene-level fog.
     @param
     overrideScene If true, you authorise this pass to override the scene's fog params with it's own settings.
     If you specify false, so other parameters are necessary, and this is the default behaviour for passes.
     @param
     mode Only applicable if overrideScene is true. You can disable fog which is turned on for the
     rest of the scene by specifying FOG_NONE. Otherwise, set a pass-specific fog mode as
     defined in the enum FogMode.
     @param
     colour The colour of the fog. Either set this to the same as your viewport background colour,
     or to blend in with a skydome or skybox.
     @param
     expDensity The density of the fog in FOG_EXP or FOG_EXP2 mode, as a value between 0 and 1.
     The default is 0.001.
     @param
     linearStart Distance in world units at which linear fog starts to encroach.
     Only applicable if mode is FOG_LINEAR.
     @param
     linearEnd Distance in world units at which linear fog becomes completely opaque.
     Only applicable if mode is FOG_LINEAR.
     */
    void setFog(
        bool overrideScene,
        FogMode mode = FogMode.FOG_NONE,
        ColourValue colour = ColourValue.White,
        Real expDensity = 0.001, Real linearStart = 0.0, Real linearEnd = 1.0 )
    {
        mFogOverride = overrideScene;
        if (overrideScene)
        {
            mFogMode = mode;
            mFogColour = colour;
            mFogStart = linearStart;
            mFogEnd = linearEnd;
            mFogDensity = expDensity;
        }
    }
    
    /** Returns true if this pass is to override the scene fog settings.
     */
    bool getFogOverride()
    {
        return mFogOverride;
    }
    
    /** Returns the fog mode for this pass.
     @note
     Only valid if getFogOverride is true.
     */
    FogMode getFogMode()
    {
        return mFogMode;
    }
    
    /** Returns the fog colour for the scene.
     */
    ColourValue getFogColour()
    {
        return mFogColour;
    }
    
    /** Returns the fog start distance for this pass.
     @note
     Only valid if getFogOverride is true.
     */
    Real getFogStart()
    {
        return mFogStart;
    }
    
    /** Returns the fog end distance for this pass.
     @note
     Only valid if getFogOverride is true.
     */
    Real getFogEnd()
    {
        return mFogEnd;
    }
    
    /** Returns the fog density for this pass.
     @note
     Only valid if getFogOverride is true.
     */
    Real getFogDensity()
    {
        return mFogDensity;
    }
    
    /** Sets the depth bias to be used for this material.
     @remarks
     When polygons are coplanar, you can get problems with 'depth fighting' where
     the pixels from the two polys compete for the same screen pixel. This is particularly
     a problem for decals (polys attached to another surface to represent details such as
     bulletholes etc.).
     @par
     A way to combat this problem is to use a depth bias to adjust the depth buffer value
     used for the decal such that it is slightly higher than the true value, ensuring that
     the decal appears on top. There are two aspects to the biasing, aant
     bias value and a slope-relative biasing value, which varies according to the
     maximum depth slope relative to the camera, ie:
     <pre>finalBias = maxSlope * slopeScaleBias + constantBias</pre>
     Note that slope scale bias, whilst more accurate, may be ignored by old hardware.
     @param constantBias The constant bias value, expressed as a factor of the
     minimum observable depth
     @param slopeScaleBias The slope-relative bias value, expressed as a factor
     of the depth slope
     */
    void setDepthBias(float constantBias, float slopeScaleBias = 0.0f)
    {
        mDepthBiasConstant = constantBias;
        mDepthBiasSlopeScale = slopeScaleBias;
    }
    
    /** Retrieves thedepth bias value as set by setDepthBias. */
    float getDepthBiasConstant()
    {
        return mDepthBiasConstant;
    }
    /** Retrieves the slope-scale depth bias value as set by setDepthBias. */
    float getDepthBiasSlopeScale()
    {
        return mDepthBiasSlopeScale;
    }
    /** Sets a factor which derives an additional depth bias from the number 
     of times a pass is iterated.
     @remarks
     The Final depth bias will be the constant depth bias as set through
     setDepthBias, plus this value times the iteration number. 
     */
    void setIterationDepthBias(float biasPerIteration)
    {
        mDepthBiasPerIteration = biasPerIteration;
    }
    /** Gets a factor which derives an additional depth bias from the number 
     of times a pass is iterated.
     */
    float getIterationDepthBias()
    {
        return mDepthBiasPerIteration;
    }
    
    /** Sets the way the pass will have use alpha to totally reject pixels from the pipeline.
     @remarks
     The default is CMPF_ALWAYS_PASS i.e. alpha is not used to reject pixels.
     @param func The comparison which must pass for the pixel to be written.
     @param value 1 byte value against which alpha values will be tested(0-255)
     @param alphaToCoverageEnabled Whether to enable alpha to coverage support
     @note
     This option applies in both the fixed function and the programmable pipeline.
     */
    void setAlphaRejectSettings(CompareFunction func, ubyte value, bool alphaToCoverageEnabled = false)
    {
        mAlphaRejectFunc = func;
        mAlphaRejectVal = value;
        mAlphaToCoverageEnabled = alphaToCoverageEnabled;
    }
    
    /** Sets the alpha reject function. See setAlphaRejectSettings for more information.
     */
    void setAlphaRejectFunction(CompareFunction func)
    {
        mAlphaRejectFunc = func;
    }
    
    /** Gets the alpha reject value. See setAlphaRejectSettings for more information.
     */
    void setAlphaRejectValue(ubyte val)
    {
        mAlphaRejectVal = val;
    }
    
    /** Gets the alpha reject function. See setAlphaRejectSettings for more information.
     */
    CompareFunction getAlphaRejectFunction(){ return mAlphaRejectFunc; }
    
    /** Gets the alpha reject value. See setAlphaRejectSettings for more information.
     */
    ubyte getAlphaRejectValue() const { return mAlphaRejectVal; }
    
    /** Sets whether to use alpha to coverage (A2C) when blending alpha rejected values. 
     @remarks
     Alpha to coverage performs multisampling on the edges of alpha-rejected
     textures to produce a smoother result. It is only supported when multisampling
     is already enabled on the render target, and when the hardware supports
     alpha to coverage (see RenderSystemCapabilities). 
     */
    void setAlphaToCoverageEnabled(bool enabled)
    {
        mAlphaToCoverageEnabled = enabled;
    }
    
    /** Gets whether to use alpha to coverage (A2C) when blending alpha rejected values. 
     */
    bool isAlphaToCoverageEnabled(){ return mAlphaToCoverageEnabled; }
    
    /** Sets whether or not transparent sorting is enabled.
     @param enabled
     If false depth sorting of this material will be disabled.
     @remarks
     By default all transparent materials are sorted such that renderables furthest
     away from the camera are rendered first. This is usually the desired behaviour
     but in certain cases this depth sorting may be unnecessary and undesirable. If
     for example it is necessary to ensure the rendering order does not change from
     one frame to the next.
     @note
     This will have no effect on non-transparent materials.
     */
    void setTransparentSortingEnabled(bool enabled)
    {
        mTransparentSorting = enabled;
    }
    
    /** Returns whether or not transparent sorting is enabled.
     */
    bool getTransparentSortingEnabled()
    {
        return mTransparentSorting;
    }
    
    /** Sets whether or not transparent sorting is forced.
     @param enabled
     If true depth sorting of this material will be depend only on the value of
     getTransparentSortingEnabled().
     @remarks
     By default even if transparent sorting is enabled, depth sorting will only be
     performed when the material is transparent and depth write/check are disabled.
     This function disables these extra conditions.
     */
    void setTransparentSortingForced(bool enabled)
    {
        mTransparentSortingForced = enabled;
    }
    
    /** Returns whether or not transparent sorting is forced.
     */
    bool getTransparentSortingForced()
    {
        return mTransparentSortingForced;
    }
    
    /** Sets whether or not this pass should iterate per light or number of
     lights which can affect the object being rendered.
     @remarks
     The default behaviour for a pass (when this option is 'false'), is
     for a pass to be rendered only once (or the number of times set in
     setPassIterationCount), with all the lights which could
     affect this object set at the same time (up to the maximum lights
     allowed in the render system, which is typically 8).
     @par
     Setting this option to 'true' changes this behaviour, such that
     instead of trying to issue render this pass once per object, it
     is run <b>per light</b>, or for a group of 'n' lights each time
     which can affect this object, the number of
     times set in setPassIterationCount (default is once). In
     this case, only light index 0 is ever used, and is a different light
     every time the pass is issued, up to the total number of lights
     which is affecting this object. This has 2 advantages:
     <ul><li>There is no limit on the number of lights which can be
     supported</li>
     <li>It's easier to write vertex / fragment programs for this because
     a single program can be used for any number of lights</li>
     </ul>
     However, this technique is more expensive, and typically you
     will want an additional ambient pass, because if no lights are 
     affecting the object it will not be rendered at all, which will look
     odd even if ambient light is zero (imagine if there are lit objects
     behind it - the objects silhouette would not show up). Therefore,
     use this option with care, and you would be well advised to provide
     a less expensive fallback technique for use in the distance.
     @note
     The number of times this pass runs is still limited by the maximum
     number of lights allowed as set in setMaxSimultaneousLights, so
     you will never get more passes than this. Also, the iteration is
     started from the 'start light' as set in Pass.setStartLight, and
     the number of passes is the number of lights to iterate over divided
     by the number of lights per iteration (default 1, set by 
     setLightCountPerIteration).
     @param enabled Whether this feature is enabled
     @param onlyForOneLightType If true, the pass will only be run for a single type
     of light, other light types will be ignored.
     @param lightType The single light type which will be considered for this pass
     */
    void setIteratePerLight(bool enabled,
                            bool onlyForOneLightType = true, Light.LightTypes lightType = Light.LightTypes.LT_POINT)
    {
        mIteratePerLight = enabled;
        mRunOnlyForOneLightType = onlyForOneLightType;
        mOnlyLightType = lightType;
    }
    
    /** Does this pass run once for every light in range? */
    bool getIteratePerLight(){ return mIteratePerLight; }
    /** Does this pass run only for a single light type (if getIteratePerLight is true). */
    bool getRunOnlyForOneLightType(){ return mRunOnlyForOneLightType; }
    /** Gets the single light type this pass runs for if  getIteratePerLight and
     getRunOnlyForOneLightType are both true. */
    Light.LightTypes getOnlyLightType(){ return mOnlyLightType; }
    
    /** If light iteration is enabled, determine the number of lights per
     iteration.
     @remarks
     The default for this setting is 1, so if you enable light iteration
     (Pass.setIteratePerLight), the pass is rendered once per light. If
     you set this value higher, the passes will occur once per 'n' lights.
     The start of the iteration is set by Pass.setStartLight and the end
     by Pass.setMaxSimultaneousLights.
     */
    void setLightCountPerIteration(ushort c)
    {
        mLightsPerIteration = c;
    }
    /** If light iteration is enabled, determine the number of lights per
     iteration.
     */
    ushort getLightCountPerIteration()
    {
        return mLightsPerIteration;
    }
    
    /// Gets the parent Technique
    Technique getParent(){ return mParent; }
    
    /// Gets the resource group of the ultimate parent Material
    string getResourceGroup()
    {
        return mParent.getResourceGroup();
    }
    
    /** Sets the details of the vertex program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the vertex program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any vertex program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setVertexProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getVertexProgramName() != name)
            {
                // Turn off vertex program if name blank
                if (name is null)
                {
                    if (mVertexProgramUsage) destroy(mVertexProgramUsage);
                    mVertexProgramUsage = null;
                }
                else
                {
                    if (!mVertexProgramUsage)
                    {
                        mVertexProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_VERTEX_PROGRAM, this);
                    }
                    mVertexProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
                
            }
        }
    }
    /** Sets the vertex program parameters.
     @remarks
     Only applicable to programmable passes, and this particular call is
     designed for low-level programs; use the named parameter methods
     for setting high-level program parameters.
     */
    void setVertexProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mVertexProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a vertex program assigned!",
                    "Pass.setVertexProgramParameters");
            }
            mVertexProgramUsage.setParameters(params);
        }
    }
    /** Gets the name of the vertex program used by this pass. */
    string getVertexProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mVertexProgramUsage)
                return "";
            else
                return mVertexProgramUsage.getProgramName();
        }
    }
    /** Gets the vertex program parameters used by this pass. */
    GpuProgramParametersPtr getVertexProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mVertexProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a vertex program assigned!",
                    "Pass.getVertexProgramParameters");
            }
            return mVertexProgramUsage.getParameters();
        }
    }
    /** Gets the vertex program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getVertexProgram()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mVertexProgramUsage.getProgram();
        }
    }
    
    
    /** Sets the details of the vertex program to use when rendering as a
     shadow caster.
     @remarks
     Texture-based shadows require that the caster is rendered to a texture
     in a solid colour (the shadow colour in the case of modulative texture
     shadows). Whilst Ogre can arrange this for the fixed function
     pipeline, passes which use vertex programs might need the vertex
     programs still to run in order to preserve any deformation etc
     that it does. However, lighting calculations must be a lot simpler,
     with only the ambient colour being used (which the engine will ensure
     is bound to the shadow colour).
     @par
     Therefore, it is up to implementors of vertex programs to provide an
     alternative vertex program which can be used to render the object
     to a shadow texture. Do all the same vertex transforms, but set the
     colour of the vertex to the ambient colour, as bound using the
     standard auto parameter binding mechanism.
     @note
     Some vertex programs will work without doing this, because Ogre ensures
     that all lights except for ambient are set black. However, the chances
     are that your vertex program is doing a lot of unnecessary work in this
     case, since the other lights are having no effect, and it is good practice
     to supply an alternative.
     @note
     This is only applicable to programmable passes.
     @par
     The default behaviour is for Ogre to switch to fixed-function
     rendering if an explicit vertex program alternative is not set.
     */
    void setShadowCasterVertexProgram(string name)
    {
        // Turn off vertex program if name blank
        if (name is null)
        {
            if (mShadowCasterVertexProgramUsage) destroy(mShadowCasterVertexProgramUsage);
            mShadowCasterVertexProgramUsage = null;
        }
        else
        {
            if (!mShadowCasterVertexProgramUsage)
            {
                mShadowCasterVertexProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_VERTEX_PROGRAM, this);
            }
            mShadowCasterVertexProgramUsage.setProgramName(name);
        }
        // Needs recompilation
        mParent._notifyNeedsRecompile();
    }
    /** Sets the vertex program parameters for rendering as a shadow caster.
     @remarks
     Only applicable to programmable passes, and this particular call is
     designed for low-level programs; use the named parameter methods
     for setting high-level program parameters.
     */
    void setShadowCasterVertexProgramParameters(GpuProgramParametersPtr params)
    {
        if (!mShadowCasterVertexProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow caster vertex program assigned!",
                "Pass.setShadowCasterVertexProgramParameters");
        }
        mShadowCasterVertexProgramUsage.setParameters(params);
    }
    /** Gets the name of the vertex program used by this pass when rendering shadow casters. */
    string getShadowCasterVertexProgramName()
    {
        if (!mShadowCasterVertexProgramUsage)
            return "";
        else
            return mShadowCasterVertexProgramUsage.getProgramName();
    }
    /** Gets the vertex program parameters used by this pass when rendering shadow casters. */
    GpuProgramParametersPtr getShadowCasterVertexProgramParameters()
    {
        if (!mShadowCasterVertexProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow caster vertex program assigned!",
                "Pass.getShadowCasterVertexProgramParameters");
        }
        return mShadowCasterVertexProgramUsage.getParameters();
    }
    /** Gets the vertex program used by this pass when rendering shadow casters,
     only available after _load(). */
    SharedPtr!GpuProgram getShadowCasterVertexProgram()
    {
        return mShadowCasterVertexProgramUsage.getProgram();
    }
    
    /** Sets the details of the fragment program to use when rendering as a
     shadow caster.
     @remarks
     Texture-based shadows require that the caster is rendered to a texture
     in a solid colour (the shadow colour in the case of modulative texture
     shadows). Whilst Ogre can arrange this for the fixed function
     pipeline, passes which use vertex programs might need the vertex
     programs still to run in order to preserve any deformation etc
     that it does. However, lighting calculations must be a lot simpler,
     with only the ambient colour being used (which the engine will ensure
     is bound to the shadow colour).
     @par
     Therefore, it is up to implementors of vertex programs to provide an
     alternative vertex program which can be used to render the object
     to a shadow texture. Do all the same vertex transforms, but set the
     colour of the vertex to the ambient colour, as bound using the
     standard auto parameter binding mechanism.
     @note
     Some vertex programs will work without doing this, because Ogre ensures
     that all lights except for ambient are set black. However, the chances
     are that your vertex program is doing a lot of unnecessary work in this
     case, since the other lights are having no effect, and it is good practice
     to supply an alternative.
     @note
     This is only applicable to programmable passes.
     @par
     The default behaviour is for Ogre to switch to fixed-function
     rendering if an explicit fragment program alternative is not set.
     */
    void setShadowCasterFragmentProgram(string name)
    {
        // Turn off fragment program if name blank
        if (name is null)
        {
            if (mShadowCasterFragmentProgramUsage) destroy(mShadowCasterFragmentProgramUsage);
            mShadowCasterFragmentProgramUsage = null;
        }
        else
        {
            if (!mShadowCasterFragmentProgramUsage)
            {
                mShadowCasterFragmentProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_FRAGMENT_PROGRAM, this);
            }
            mShadowCasterFragmentProgramUsage.setProgramName(name);
        }
        // Needs recompilation
        mParent._notifyNeedsRecompile();
    }
    /** Sets the fragment program parameters for rendering as a shadow caster.
     @remarks
     Only applicable to programmable passes, and this particular call is
     designed for low-level programs; use the named parameter methods
     for setting high-level program parameters.
     */
    void setShadowCasterFragmentProgramParameters(GpuProgramParametersPtr params)
    {
        if (Root.getSingleton().getRenderSystem().getName().indexOf("OpenGL ES 2") != -1)
        {
            if (!mShadowCasterFragmentProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a shadow caster fragment program assigned!",
                    "Pass.setShadowCasterFragmentProgramParameters");
            }
            mShadowCasterFragmentProgramUsage.setParameters(params);
        }
    }
    /** Gets the name of the fragment program used by this pass when rendering shadow casters. */
    string getShadowCasterFragmentProgramName()
    {
        if (!mShadowCasterFragmentProgramUsage)
            return "";
        else
            return mShadowCasterFragmentProgramUsage.getProgramName();
    }
    /** Gets the fragment program parameters used by this pass when rendering shadow casters. */
    GpuProgramParametersPtr getShadowCasterFragmentProgramParameters()
    {
        if (Root.getSingleton().getRenderSystem().getName().indexOf("OpenGL ES 2") != -1)
        {
            if (!mShadowCasterFragmentProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a shadow caster fragment program assigned!",
                    "Pass.getShadowCasterFragmentProgramParameters");
            }
        }
        return mShadowCasterFragmentProgramUsage.getParameters();
    }
    /** Gets the fragment program used by this pass when rendering shadow casters,
     only available after _load(). */
    SharedPtr!GpuProgram getShadowCasterFragmentProgram()
    {
        return mShadowCasterFragmentProgramUsage.getProgram();
    }
    
    /** Sets the details of the vertex program to use when rendering as a
     shadow receiver.
     @remarks
     Texture-based shadows require that the shadow receiver is rendered using
     a projective texture. Whilst Ogre can arrange this for the fixed function
     pipeline, passes which use vertex programs might need the vertex
     programs still to run in order to preserve any deformation etc
     that it does. So in this case, we need a vertex program which does the
     appropriate vertex transformation, but generates projective texture
     coordinates.
     @par
     Therefore, it is up to implementors of vertex programs to provide an
     alternative vertex program which can be used to render the object
     as a shadow receiver. Do all the same vertex transforms, but generate
     <strong>2 sets</strong> of texture coordinates using the auto parameter
     ACT_TEXTURE_VIEWPROJ_MATRIX, which Ogre will bind to the parameter name /
     index you supply as the second parameter to this method. 2 texture
     sets are needed because Ogre needs to use 2 texture units for some
     shadow effects.
     @note
     This is only applicable to programmable passes.
     @par
     The default behaviour is for Ogre to switch to fixed-function
     rendering if an explict vertex program alternative is not set.
     */
    void setShadowReceiverVertexProgram(string name)
    {
        // Turn off vertex program if name blank
        if (name is null)
        {
            if (mShadowReceiverVertexProgramUsage) destroy(mShadowReceiverVertexProgramUsage);
            mShadowReceiverVertexProgramUsage = null;
        }
        else
        {
            if (!mShadowReceiverVertexProgramUsage)
            {
                mShadowReceiverVertexProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_VERTEX_PROGRAM, this);
            }
            mShadowReceiverVertexProgramUsage.setProgramName(name);
        }
        // Needs recompilation
        mParent._notifyNeedsRecompile();
    }
    /** Sets the vertex program parameters for rendering as a shadow receiver.
     @remarks
     Only applicable to programmable passes, and this particular call is
     designed for low-level programs; use the named parameter methods
     for setting high-level program parameters.
     */
    void setShadowReceiverVertexProgramParameters(GpuProgramParametersPtr params)
    {
        if (!mShadowReceiverVertexProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow receiver vertex program assigned!",
                "Pass.setShadowReceiverVertexProgramParameters");
        }
        mShadowReceiverVertexProgramUsage.setParameters(params);
    }
    
    /** This method allows you to specify a fragment program for use when
     rendering a texture shadow receiver.
     @remarks
     Texture shadows are applied by rendering the receiver. Modulative texture
     shadows are performed as a post-render darkening pass, and as such
     fragment programs are generally not required per-object. Additive
     texture shadows, however, are applied by accumulating light masked
     out using a texture shadow (black & white by default, unless you
     customise this using SceneManager.setCustomShadowCasterMaterial).
     OGRE can do this for you for most materials, but if you use a custom
     lighting program (e.g. per pixel lighting) then you'll need to provide
     a custom version for receiving shadows. You don't need to provide
     this for shadow casters if you don't use self-shadowing since they
     will never be shadow receivers too.
     @par
     The shadow texture is always bound to texture unit 0 when rendering
     texture shadow passes. Therefore your custom shadow receiver program
     may well just need to shift it's texture unit usage up by one unit,
     and take the shadow texture into account in its calculations.
     */
    void setShadowReceiverFragmentProgram(string name)
    {
        // Turn off Fragment program if name blank
        if (name is null)
        {
            if (mShadowReceiverFragmentProgramUsage) destroy(mShadowReceiverFragmentProgramUsage);
            mShadowReceiverFragmentProgramUsage = null;
        }
        else
        {
            if (!mShadowReceiverFragmentProgramUsage)
            {
                mShadowReceiverFragmentProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_FRAGMENT_PROGRAM, this);
            }
            mShadowReceiverFragmentProgramUsage.setProgramName(name);
        }
        // Needs recompilation
        mParent._notifyNeedsRecompile();
    }
    /** Sets the fragment program parameters for rendering as a shadow receiver.
     @remarks
     Only applicable to programmable passes, and this particular call is
     designed for low-level programs; use the named parameter methods
     for setting high-level program parameters.
     */
    void setShadowReceiverFragmentProgramParameters(GpuProgramParametersPtr params)
    {
        if (!mShadowReceiverFragmentProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow receiver fragment program assigned!",
                "Pass.setShadowReceiverFragmentProgramParameters");
        }
        mShadowReceiverFragmentProgramUsage.setParameters(params);
    }
    
    /** Gets the name of the vertex program used by this pass when rendering shadow receivers. */
    string getShadowReceiverVertexProgramName()
    {
        if (!mShadowReceiverVertexProgramUsage)
            return "";
        else
            return mShadowReceiverVertexProgramUsage.getProgramName();
    }
    /** Gets the vertex program parameters used by this pass when rendering shadow receivers. */
    GpuProgramParametersPtr getShadowReceiverVertexProgramParameters()
    {
        if (!mShadowReceiverVertexProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow receiver vertex program assigned!",
                "Pass.getShadowReceiverVertexProgramParameters");
        }
        return mShadowReceiverVertexProgramUsage.getParameters();
    }
    /** Gets the vertex program used by this pass when rendering shadow receivers,
     only available after _load(). */
    SharedPtr!GpuProgram getShadowReceiverVertexProgram()
    {
        return mShadowReceiverVertexProgramUsage.getProgram();
    }
    
    /** Gets the name of the fragment program used by this pass when rendering shadow receivers. */
    string getShadowReceiverFragmentProgramName()
    {
        if (!mShadowReceiverFragmentProgramUsage)
            return "";
        else
            return mShadowReceiverFragmentProgramUsage.getProgramName();
    }
    /** Gets the fragment program parameters used by this pass when rendering shadow receivers. */
    GpuProgramParametersPtr getShadowReceiverFragmentProgramParameters()
    {
        if (!mShadowReceiverFragmentProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a shadow receiver fragment program assigned!",
                "Pass.getShadowReceiverFragmentProgramParameters");
        }
        return mShadowReceiverFragmentProgramUsage.getParameters();
    }
    
    /** Gets the fragment program used by this pass when rendering shadow receivers,
     only available after _load(). */
    SharedPtr!GpuProgram getShadowReceiverFragmentProgram()
    {
        return mShadowReceiverFragmentProgramUsage.getProgram();
    }
    
    /** Sets the details of the fragment program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the fragment program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any fragment program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setFragmentProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getFragmentProgramName() != name)
            {
                // Turn off fragment program if name blank
                if (name is null)
                {
                    if (mFragmentProgramUsage) destroy(mFragmentProgramUsage);
                    mFragmentProgramUsage = null;
                }
                else
                {
                    if (!mFragmentProgramUsage)
                    {
                        mFragmentProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_FRAGMENT_PROGRAM, this);
                    }
                    mFragmentProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
            }
        }
    }
    /** Sets the fragment program parameters.
     @remarks
     Only applicable to programmable passes.
     */
    void setFragmentProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
            if (!mFragmentProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a fragment program assigned!",
                "Pass.setFragmentProgramParameters");
        }
        mFragmentProgramUsage.setParameters(params);
    }
    /** Gets the name of the fragment program used by this pass. */
    string getFragmentProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
            if (!mFragmentProgramUsage)
                return "";
        else
            return mFragmentProgramUsage.getProgramName();
    }
    
    /** Gets the fragment program parameters used by this pass. */
    GpuProgramParametersPtr getFragmentProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
            return mFragmentProgramUsage.getParameters();
    }
    /** Gets the fragment program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getFragmentProgram()
    {
        synchronized(mGpuProgramChangeMutex)
            return mFragmentProgramUsage.getProgram();
    }
    
    /** Sets the details of the geometry program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the geometry program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any geometry program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setGeometryProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getGeometryProgramName() != name)
            {
                // Turn off geometry program if name blank
                if (name is null)
                {
                    if (mGeometryProgramUsage) destroy(mGeometryProgramUsage);
                    mGeometryProgramUsage = null;
                }
                else
                {
                    if (!mGeometryProgramUsage)
                    {
                        mGeometryProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_GEOMETRY_PROGRAM, this);
                    }
                    mGeometryProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( Pass.getHashFunction() == Pass.getBuiltinHashFunction( Pass.BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
            }
        }
    }
    /** Sets the geometry program parameters.
     @remarks
     Only applicable to programmable passes.
     */
    void setGeometryProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
            if (!mGeometryProgramUsage)
        {
            throw new InvalidParamsError(
                "This pass does not have a geometry program assigned!",
                "Pass.setGeometryProgramParameters");
        }
        mGeometryProgramUsage.setParameters(params);
    }
    /** Gets the name of the geometry program used by this pass. */
    string getGeometryProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
            if (!mGeometryProgramUsage)
                return "";
        else
            return mGeometryProgramUsage.getProgramName();
    }
    /** Gets the geometry program parameters used by this pass. */
    GpuProgramParametersPtr getGeometryProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
            return mGeometryProgramUsage.getParameters();
    }
    /** Gets the geometry program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getGeometryProgram()
    {
        synchronized(mGpuProgramChangeMutex)
            return mGeometryProgramUsage.getProgram();
    }
    
    /** Splits this Pass to one which can be handled in the number of
     texture units specified.
     @remarks
     Only works on non-programmable passes, programmable passes cannot be
     split, it's up to the author to ensure that there is a fallback Technique
     for less capable cards.
     @param numUnits The target number of texture units
     @return A new Pass which contains the remaining units, and a scene_blend
     setting appropriate to approximate the multitexture. This Pass will be
     attached to the parent Technique of this Pass.
     */
    Pass _split(ushort numUnits)
    {
        if (mVertexProgramUsage || mGeometryProgramUsage || mFragmentProgramUsage)
        {
            throw new InvalidParamsError( "Programmable passes cannot be "
                                         "automatically split, define a fallback technique instead.",
                                         "Pass._split");
        }
        
        if (mTextureUnitStates.length > numUnits)
        {
            size_t start = mTextureUnitStates.length - numUnits;
            
            Pass newPass = mParent.createPass();
            
            //TextureUnitStates.iterator istart, i, iend;
            
            //i = istart = mTextureUnitStates.begin() + start;
            auto i = mTextureUnitStates[start];
            // Set the new pass to fallback using scene blend
            newPass.setSceneBlending(
                i.getColourBlendFallbackSrc(), i.getColourBlendFallbackDest());
            // Fixup the texture unit 0   of new pass   blending method   to replace
            // all colour and alpha   with texture without adjustment, because we
            // assume it's detail texture.
            i.setColourOperationEx(LayerBlendOperationEx.LBX_SOURCE1,   LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
            i.setAlphaOperation(LayerBlendOperationEx.LBX_SOURCE1, LayerBlendSource.LBS_TEXTURE, LayerBlendSource.LBS_CURRENT);
            
            // Add all the other texture unit states
            //foreach (; i != iend; ++i)
            foreach (t; mTextureUnitStates[start .. $])
            {
                // detach from parent first
                t._notifyParent(null);
                newPass.addTextureUnitState(t);
            }
            // Now remove texture units from this Pass, we don't need to delete since they've
            // been transferred
            //mTextureUnitStates.removeFromArray(mTextureUnitStates[start .. $]);
            mTextureUnitStates.length = start;
            _dirtyHash();
            mContentTypeLookupBuilt = false;
            return newPass;
        }
        return null;
    }
    
    /** Internal method to adjust pass index. */
    void _notifyIndex(ushort index)
    {
        if (mIndex != index)
        {
            mIndex = index;
            _dirtyHash();
        }
    }
    
    /** Internal method for preparing to load this pass. */
    void _prepare()
    {
        // We assume the Technique only calls this when the material is being
        // prepared
        
        // prepare each TextureUnitState
        foreach (i; mTextureUnitStates)
        {
            i._prepare();
        }
        
    }
    /** Internal method for undoing the load preparartion for this pass. */
    void _unprepare()
    {
        // unprepare each TextureUnitState
        foreach (i; mTextureUnitStates)
        {
            i._unprepare();
        }
        
    }
    /** Internal method for loading this pass. */
    void _load()
    {
        // We assume the Technique only calls this when the material is being
        // loaded
        
        // Load each TextureUnitState
        foreach (i; mTextureUnitStates)
        {
            i._load();
        }
        
        // Load programs
        if (mVertexProgramUsage)
        {
            // Load vertex program
            mVertexProgramUsage._load();
        }
        if (mShadowCasterVertexProgramUsage)
        {
            // Load vertex program
            mShadowCasterVertexProgramUsage._load();
        }
        if (mShadowCasterFragmentProgramUsage)
        {
            // Load fragment program
            mShadowCasterFragmentProgramUsage._load();
        }
        if (mShadowReceiverVertexProgramUsage)
        {
            // Load vertex program
            mShadowReceiverVertexProgramUsage._load();
        }
        
        if (mTesselationHullProgramUsage)
        {
            // Load tesselation control program
            mTesselationHullProgramUsage._load();
        }
        
        if (mTesselationDomainProgramUsage)
        {
            // Load tesselation evaluation program
            mTesselationDomainProgramUsage._load();
        }
        
        if (mGeometryProgramUsage)
        {
            // Load geometry program
            mGeometryProgramUsage._load();
        }
        
        if (mFragmentProgramUsage)
        {
            // Load fragment program
            mFragmentProgramUsage._load();
        }
        if (mShadowReceiverFragmentProgramUsage)
        {
            // Load Fragment program
            mShadowReceiverFragmentProgramUsage._load();
        }
        
        if (mComputeProgramUsage)
        {
            // Load compute program
            mComputeProgramUsage._load();
        }
        
        if (mHashDirtyQueued)
        {
            _dirtyHash();
        }
        
    }
    /** Internal method for unloading this pass. */
    void _unload()
    {
        // Unload each TextureUnitState
        
        
        foreach (i; mTextureUnitStates)
        {
            i._unload();
        }
        
        // Unload programs
        if (mVertexProgramUsage)
        {
            // TODO
        }
        if (mGeometryProgramUsage)
        {
            // TODO
        }
        if (mFragmentProgramUsage)
        {
            // TODO
        }
        if (mTesselationHullProgramUsage)
        {
            // TODO
        }
        if (mTesselationDomainProgramUsage)
        {
            // TODO
        }
        if (mComputeProgramUsage)
        {
            // TODO
        }
        if (mGeometryProgramUsage)
        {
            // TODO
        }
    }
    // Is this loaded?
    bool isLoaded()
    {
        return mParent.isLoaded();
    }
    
    /** Gets the 'hash' of this pass, ie a precomputed number to use for sorting
     @remarks
     This hash is used to sort passes, and for this reason the pass is hashed
     using firstly its index (so that all passes are rendered in order), then
     by the textures which it's TextureUnitState instances are using.
     */
    uint getHash(){ return mHash; }
    /// Mark the hash as dirty
    void _dirtyHash()
    {
        Material mat = mParent.getParent();
        if (mat.isLoading() || mat.isLoaded())
        {
            synchronized(msDirtyHashListMutex)
            {
                // Mark this hash as for follow up
                msDirtyHashList.insert(this);
                mHashDirtyQueued = false;
            }
        }
        else
        {
            mHashDirtyQueued = true;
        }
    }
    /** Internal method for recalculating the hash.
     @remarks
     Do not call this unless you are sure the old hash is not still being
     used by anything. If in doubt, call _dirtyHash if you want to force
     recalculation of the has next time.
     */
    void _recalculateHash()
    {
        /* Hash format is 32-bit, divided as follows (high to low bits)
         bits   purpose
         4     Pass index (i.e. max 16 passes!)
         14     Hashed texture name from unit 0
         14     Hashed texture name from unit 1

         Note that at the moment we don't sort on the 3rd texture unit plus
         on the assumption that these are less frequently used; sorting on
         the first 2 gives us the most benefit for now.
         */
        mHash = msHashFunc(this);
    }
    /** Tells the pass that it needs recompilation. */
    void _notifyNeedsRecompile()
    {
        mParent._notifyNeedsRecompile();
    }
    
    /** Update automatic parameters.
     @param source The source of the parameters
     @param variabilityMask A mask of GpuParamVariability which identifies which autos will need updating
     */
    void _updateAutoParams(AutoParamDataSource source, ushort variabilityMask)
    {
        if (hasVertexProgram())
        {
            // Update vertex program auto params
            mVertexProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
        
        if (hasGeometryProgram())
        {
            // Update geometry program auto params
            mGeometryProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
        
        if (hasFragmentProgram())
        {
            // Update fragment program auto params
            mFragmentProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
        
        if (hasTesselationHullProgram())
        {
            // Update fragment program auto params
            mTesselationHullProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
        
        if (hasTesselationDomainProgram())
        {
            // Update fragment program auto params
            mTesselationDomainProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
        
        if (hasComputeProgram())
        {
            // Update fragment program auto params
            mComputeProgramUsage.getParameters().get()._updateAutoParams(source, variabilityMask);
        }
    }
    
    /** Gets the 'nth' texture which references the given content type.
     @remarks
     If the 'nth' texture unit which references the content type doesn't
     exist, then this method returns an arbitrary high-value outside the
     valid range to index texture units.
     */
    ushort _getTextureUnitWithContentTypeIndex(
        TextureUnitState.ContentType contentType, ushort index)
    {
        if (!mContentTypeLookupBuilt)
        {
            mShadowContentTypeLookup.clear();
            for (ushort i = 0; i < mTextureUnitStates.length; ++i)
            {
                if (mTextureUnitStates[i].getContentType() == TextureUnitState.ContentType.CONTENT_SHADOW)
                {
                    mShadowContentTypeLookup.insert(i);
                }
            }
            mContentTypeLookupBuilt = true;
        }
        
        switch(contentType)
        {
            case TextureUnitState.ContentType.CONTENT_SHADOW:
                if (index < mShadowContentTypeLookup.length)
                {
                    return mShadowContentTypeLookup[index];
                }
                break;
            default:
                // Simple iteration
                for (ushort i = 0; i < mTextureUnitStates.length; ++i)
                {
                    if (mTextureUnitStates[i].getContentType() == TextureUnitState.ContentType.CONTENT_SHADOW)
                    {
                        if (index == 0)
                        {
                            return i;
                        }
                        else
                        {
                            --index;
                        }
                    }
                }
                break;
        }
        
        // not found - return out of range
        return cast(ushort)(mTextureUnitStates.length + 1);
        
    }
    
    /** Set texture filtering for every texture unit 
     @note
     This property actually exists on the TextureUnitState class
     For simplicity, this method allows you to set these properties for
     every current TeextureUnitState, If you need more precision, retrieve the
     TextureUnitState instance and set the property there.
     @see TextureUnitState.setTextureFiltering
     */
    void setTextureFiltering(TextureFilterOptions filterType)
    {
        synchronized(mTexUnitChangeMutex)
            
            
            
            foreach (i; mTextureUnitStates)
        {
            i.setTextureFiltering(filterType);
        }
    }
    /** Sets the anisotropy level to be used for all textures.
     @note
     This property has been moved to the TextureUnitState class, which is accessible via the
     Technique and Pass. For simplicity, this method allows you to set these properties for
     every current TeextureUnitState, If you need more precision, retrieve the Technique,
     Pass and TextureUnitState instances and set the property there.
     @see TextureUnitState.setTextureAnisotropy
     */
    void setTextureAnisotropy(uint maxAniso)
    {
        synchronized(mTexUnitChangeMutex)
        {
            foreach (i; mTextureUnitStates)
            {
                i.setTextureAnisotropy(maxAniso);
            }
        }
    }
    /** If set to true, this forces normals to be normalised dynamically 
     by the hardware for this pass.
     @remarks
     This option can be used to prevent lighting variations when scaling an
     object - normally because this scaling is hardware based, the normals 
     get scaled too which causes lighting to become inconsistent. By default the
     SceneManager detects scaled objects and does this for you, but 
     this has an overhead so you might want to turn that off through
     SceneManager.setNormaliseNormalsOnScale(false) and only do it per-Pass
     when you need to.
     */
    void setNormaliseNormals(bool normalise) { mNormaliseNormals = normalise; }
    
    /** Returns true if this pass has auto-normalisation of normals set. */
    bool getNormaliseNormals(){return mNormaliseNormals; }
    
    /** Static method to retrieve all the Passes which need their
     hash values recalculated.
     */
    static /+const+/ PassSet getDirtyHashList()
    { return msDirtyHashList; }
    /** Static method to retrieve all the Passes which are pending deletion.
     */
    static /+const+/ PassSet getPassGraveyard()
    { return msPassGraveyard; }
    /** Static method to reset the list of passes which need their hash
     values recalculated.
     @remarks
     For performance, the dirty list is not updated progressively as
     the hashes are recalculated, instead we expect the processor of the
     dirty hash list to clear the list when they are done.
     */
    static void clearDirtyHashList()
    { 
        synchronized(msDirtyHashListMutex)
            msDirtyHashList.clear(); 
    }
    
    /** Process all dirty and pending deletion passes. */
    static void processPendingPassUpdates()
    {
        synchronized(msPassGraveyardMutex)
        {
            // Delete items in the graveyard
            foreach (i; msPassGraveyard)
            {
                destroy(i);
            }
            msPassGraveyard.clear();
        }

        PassSet tempDirtyHashList;
        synchronized(msDirtyHashListMutex)
        {
            // The dirty ones will have been removed from the groups above using the old hash now
            tempDirtyHashList.swap(msDirtyHashList);
        }

        foreach (p; tempDirtyHashList)
        {
            p._recalculateHash();
        }
    }
    
    /** Queue this pass for deletion when appropriate. */
    void queueForDeletion()
    {
        mQueuedForDeletion = true;
        
        removeAllTextureUnitStates();
        if (mVertexProgramUsage)
        {
            destroy(mVertexProgramUsage);
            mVertexProgramUsage = null;
        }
        if (mShadowCasterVertexProgramUsage)
        {
            destroy(mShadowCasterVertexProgramUsage);
            mShadowCasterVertexProgramUsage = null;
        }
        if (mShadowCasterFragmentProgramUsage)
        {
            destroy(mShadowCasterFragmentProgramUsage);
            mShadowCasterFragmentProgramUsage = null;
        }
        if (mShadowReceiverVertexProgramUsage)
        {
            destroy(mShadowReceiverVertexProgramUsage);
            mShadowReceiverVertexProgramUsage = null;
        }
        if (mGeometryProgramUsage)
        {
            destroy(mGeometryProgramUsage);
            mGeometryProgramUsage = null;
        }
        if (mFragmentProgramUsage)
        {
            destroy(mFragmentProgramUsage);
            mFragmentProgramUsage = null;
        }
        if (mTesselationHullProgramUsage)
        {
            destroy(mTesselationHullProgramUsage);
            mTesselationHullProgramUsage = null;
        }
        if (mTesselationDomainProgramUsage)
        {
            destroy(mTesselationDomainProgramUsage);
            mTesselationDomainProgramUsage = null;
        }
        if (mComputeProgramUsage)
        {
            destroy(mComputeProgramUsage);
            mComputeProgramUsage = null;
        }
        if (mShadowReceiverFragmentProgramUsage)
        {
            destroy(mShadowReceiverFragmentProgramUsage);
            mShadowReceiverFragmentProgramUsage = null;
        }
        // remove from dirty list, if there
        synchronized(msDirtyHashListMutex)
        {
            msDirtyHashList.removeFromArray(this);
        }
        synchronized(msPassGraveyardMutex)
        {
            msPassGraveyard.insert(this);
        }
    }
    
    /** Returns whether this pass is ambient only.
     */
    bool isAmbientOnly()
    {
        // treat as ambient if lighting is off, or colour write is off,
        // or all non-ambient (& emissive) colours are black
        // NB a vertex program could override this, but passes using vertex
        // programs are expected to indicate they are ambient only by
        // setting the state so it matches one of the conditions above, even
        // though this state is not used in rendering.
        return (!mLightingEnabled || !mColourWrite ||
                (mDiffuse == ColourValue.Black &&
         mSpecular == ColourValue.Black));
    }
    
    /** set the number of iterations that this pass
     should perform when doing fast multi pass operation.
     @remarks
     Only applicable for programmable passes.
     @param count number of iterations to perform fast multi pass operations.
     A value greater than 1 will cause the pass to be executed count number of
     times without changing the render state.  This is very useful for passes
     that use programmable shaders that have to iterate more than once but don't
     need a render state change.  Using multi pass can dramatically speed up rendering
     for materials that do things like fur, blur.
     A value of 1 turns off multi pass operation and the pass does
     the normal pass operation.
     */
    void setPassIterationCount(size_t count) { mPassIterationCount = count; }
    
    /** Gets the pass iteration count value.
     */
    size_t getPassIterationCount(){ return mPassIterationCount; }
    
    /** Applies texture names to Texture Unit State with matching texture name aliases.
     All Texture Unit States within the pass are checked.
     If matching texture aliases are found then true is returned.

     @param
     aliasList is a map container of texture alias, texture name pairs
     @param
     apply set true to apply the texture aliases else just test to see if texture alias matches are found.
     @return
     True if matching texture aliases were found in the pass.
     */
    bool applyTextureAliases(AliasTextureNamePairList aliasList,bool apply = true)
    {
        // iterate through each texture unit state and apply the texture alias if it applies
        bool testResult = false;
        
        foreach (i; mTextureUnitStates)
        {
            if (i.applyTextureAliases(aliasList, apply))
                testResult = true;
        }
        
        return testResult;
        
    }
    
    /** Sets whether or not this pass will be clipped by a scissor rectangle
     encompassing the lights that are being used in it.
     @remarks
     In order to cut down on fillrate when you have a number of fixed-range
     lights in the scene, you can enable this option to request that
     during rendering, only the region of the screen which is covered by
     the lights is rendered. This region is the screen-space rectangle 
     covering the union of the spheres making up the light ranges. Directional
     lights are ignored for this.
     @par
     This is only likely to be useful for multipass additive lighting 
     algorithms, where the scene has already been 'seeded' with an ambient 
     pass and this pass is just adding light in affected areas.
     @note
     When using SHADOWTYPE_STENCIL_ADDITIVE or SHADOWTYPE_TEXTURE_ADDITIVE,
     this option is implicitly used for all per-light passes and does
     not need to be specified. If you are not using shadows or are using
     a modulative or an integrated shadow technique then this could be useful.

     */
    void setLightScissoringEnabled(bool enabled) { mLightScissoring = enabled; }
    /** Gets whether or not this pass will be clipped by a scissor rectangle
     encompassing the lights that are being used in it.
     */
    bool getLightScissoringEnabled(){ return mLightScissoring; }
    
    /** Gets whether or not this pass will be clipped by user clips planes
     bounding the area covered by the light.
     @remarks
     In order to cut down on the geometry set up to render this pass 
     when you have a single fixed-range light being rendered through it, 
     you can enable this option to request that during triangle setup, 
     clip planes are defined to bound the range of the light. In the case
     of a point light these planes form a cube, and in the case of 
     a spotlight they form a pyramid. Directional lights are never clipped.
     @par
     This option is only likely to be useful for multipass additive lighting 
     algorithms, where the scene has already been 'seeded' with an ambient 
     pass and this pass is just adding light in affected areas. In addition,
     it will only be honoured if there is exactly one non-directional light
     being used in this pass. Also, these clip planes override any user clip
     planes set on Camera.
     @note
     When using SHADOWTYPE_STENCIL_ADDITIVE or SHADOWTYPE_TEXTURE_ADDITIVE,
     this option is automatically used for all per-light passes if you 
     enable SceneManager.setShadowUseLightClipPlanes and does
     not need to be specified. It is disabled by default since clip planes have
     a cost of their own which may not always exceed the benefits they give you.
     */
    void setLightClipPlanesEnabled(bool enabled) { mLightClipPlanes = enabled; }
    /** Gets whether or not this pass will be clipped by user clips planes
     bounding the area covered by the light.
     */
    bool getLightClipPlanesEnabled(){ return mLightClipPlanes; }
    
    /** Manually set which illumination stage this pass is a member of.
     @remarks
     When using an additive lighting mode (SHADOWTYPE_STENCIL_ADDITIVE or
     SHADOWTYPE_TEXTURE_ADDITIVE), the scene is rendered in 3 discrete
     stages, ambient (or pre-lighting), per-light (once per light, with 
     shadowing) and decal (or post-lighting). Usually OGRE figures out how
     to categorise your passes automatically, but there are some effects you
     cannot achieve without manually controlling the illumination. For example
     specular effects are muted by the typical sequence because all textures
     are saved until the IS_DECAL stage which mutes the specular effect. 
     Instead, you could do texturing within the per-light stage if it's
     possible for your material and thus add the specular on after the
     decal texturing, and have no post-light rendering. 
     @par
     If you assign an illumination stage to a pass you have to assign it
     to all passes in the technique otherwise it will be ignored. Also note
     that whilst you can have more than one pass in each group, they cannot
     alternate, ie all ambient passes will be before all per-light passes, 
     which will also be before all decal passes. Within their categories
     the passes will retain their ordering though.
     */
    void setIlluminationStage(IlluminationStage _is) { mIlluminationStage = _is; }
    /// Get the manually assigned illumination stage, if any
    IlluminationStage getIlluminationStage(){ return mIlluminationStage; }
    /** There are some default hash functions used to order passes so that
     render state changes are minimised, this enumerates them.
     */
    enum BuiltinHashFunction
    {
        /** Try to minimise the number of texture changes. */
        MIN_TEXTURE_CHANGE,
        /** Try to minimise the number of GPU program changes.
         @note Only really useful if you use GPU programs for all of your
         materials. 
         */
        MIN_GPU_PROGRAM_CHANGE
    }
    /** Sets one of the default hash functions to be used.
     @remarks
     You absolutely must not change the hash function whilst any Pass instances
     exist in the render queue. The only time you can do this is either
     before you render anything, or directly after you manuall call
     RenderQueue.clear(true) to completely destroy the queue structures.
     The default is MIN_TEXTURE_CHANGE.
     @note
     You can also implement your own hash function, see the alternate version
     of this method.
     @see HashFunc
     */
    static void setHashFunction(BuiltinHashFunction builtin)
    {
        final switch(builtin)
        {
            case BuiltinHashFunction.MIN_TEXTURE_CHANGE:
                msHashFunc = &MinTextureStateChangeHashFunc;
                break;
            case BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE:
                msHashFunc = &MinGpuProgramChangeHashFunc;
                break;
        }
    }
    
    /** Set the hash function used for all passes.
     @remarks
     You absolutely must not change the hash function whilst any Pass instances
     exist in the render queue. The only time you can do this is either
     before you render anything, or directly after you manuall call
     RenderQueue.clear(true) to completely destroy the queue structures.
     @note
     You can also use one of the built-in hash functions, see the alternate version
     of this method. The default is MIN_TEXTURE_CHANGE.
     @see HashFunc
     */
    static void setHashFunction(HashFunc hashFunc) { msHashFunc = hashFunc; }
    
    /** Get the hash function used for all passes.
     */
    static HashFunc getHashFunction() { return msHashFunc; }
    
    /** Get the builtin hash function.
     */
    static HashFunc getBuiltinHashFunction(BuiltinHashFunction builtin)
    {
        Pass.HashFunc hashFunc = null;
        
        final switch(builtin)
        {
            case BuiltinHashFunction.MIN_TEXTURE_CHANGE:
                hashFunc = &MinTextureStateChangeHashFunc;
                break;
            case BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE:
                hashFunc = &MinGpuProgramChangeHashFunc;
                break;
        }
        
        return hashFunc;
    }
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.
     */
    UserObjectBindings getUserObjectBindings() { return mUserObjectBindings; }
    
    /** Return an instance of user objects binding associated with this class.
     You can use it to associate one or more custom objects with this class instance.
     @see UserObjectBindings.setUserAny.        
     */
    const(UserObjectBindings) getUserObjectBindings() const { return mUserObjectBindings; }
    
    /// Support for shader model 5.0, hull and domain shaders
    /** Sets the details of the tesselation control program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the Tesselation Hull program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any Tesselation Hull program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setTesselationHullProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getTesselationHullProgramName() != name)
            {
                // Turn off tesselation Hull program if name blank
                if (name is null)
                {
                    if (mTesselationHullProgramUsage) destroy(mTesselationHullProgramUsage);
                    mTesselationHullProgramUsage = null;
                }
                else
                {
                    if (!mTesselationHullProgramUsage)
                    {
                        mTesselationHullProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_HULL_PROGRAM, this);
                    }
                    mTesselationHullProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( getHashFunction() == getBuiltinHashFunction( BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
            }
        }
    }
    /** Sets the Tesselation Hull program parameters.
     @remarks
     Only applicable to programmable passes.
     */
    void setTesselationHullProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mTesselationHullProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a tesselation Hull program assigned!",
                    "Pass.setTesselationHullProgramParameters");
            }
            mTesselationHullProgramUsage.setParameters(params);
        }
    }
    /** Gets the name of the Tesselation Hull program used by this pass. */
    string getTesselationHullProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mTesselationHullProgramUsage)
                return "";
            else
                return mTesselationHullProgramUsage.getProgramName();
        }
    }
    /** Gets the Tesselation Hull program parameters used by this pass. */
    GpuProgramParametersPtr getTesselationHullProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mTesselationHullProgramUsage.getParameters();
        }
    }
    /** Gets the Tesselation Hull program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getTesselationHullProgram()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mTesselationHullProgramUsage.getProgram();
        }
    }
    
    /** Sets the details of the tesselation domain program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the Tesselation domain program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any Tesselation domain program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setTesselationDomainProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getTesselationDomainProgramName() != name)
            {
                // Turn off tesselation Domain program if name blank
                if (name is null)
                {
                    if (mTesselationDomainProgramUsage) destroy(mTesselationDomainProgramUsage);
                    mTesselationDomainProgramUsage = null;
                }
                else
                {
                    if (!mTesselationDomainProgramUsage)
                    {
                        mTesselationDomainProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_DOMAIN_PROGRAM, this);
                    }
                    mTesselationDomainProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( getHashFunction() == getBuiltinHashFunction( BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
            }
        }
    }
    /** Sets the Tesselation Domain program parameters.
     @remarks
     Only applicable to programmable passes.
     */
    void setTesselationDomainProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mTesselationDomainProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a tesselation Domain program assigned!",
                    "Pass.setTesselationDomainProgramParameters");
            }
            mTesselationDomainProgramUsage.setParameters(params);
        }
    }
    /** Gets the name of the Domain Evaluation program used by this pass. */
    string getTesselationDomainProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mTesselationDomainProgramUsage)
                return "";
            else
                return mTesselationDomainProgramUsage.getProgramName();
        }
    }
    /** Gets the Tesselation Domain program parameters used by this pass. */
    GpuProgramParametersPtr getTesselationDomainProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mTesselationDomainProgramUsage.getParameters();
        }
    }
    /** Gets the Tesselation Domain program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getTesselationDomainProgram()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mTesselationDomainProgramUsage.getProgram();
        }
    }
    
    /** Sets the details of the compute program to use.
     @remarks
     Only applicable to programmable passes, this sets the details of
     the compute program to use in this pass. The program will not be
     loaded until the parent Material is loaded.
     @param name The name of the program - this must have been
     created using GpuProgramManager by the time that this Pass
     is loaded. If this parameter is blank, any compute program in this pass is disabled.
     @param resetParams
     If true, this will create a fresh set of parameters from the
     new program being linked, so if you had previously set parameters
     you will have to set them again. If you set this to false, you must
     be absolutely sure that the parameters match perfectly, and in the
     case of named parameters refers to the indexes underlying them,
     not just the names.
     */
    void setComputeProgram(string name, bool resetParams = true)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (getComputeProgramName() != name)
            {
                // Turn off compute program if name blank
                if (name is null)
                {
                    if (mComputeProgramUsage) destroy(mComputeProgramUsage);
                    mComputeProgramUsage = null;
                }
                else
                {
                    if (!mComputeProgramUsage)
                    {
                        mComputeProgramUsage = new GpuProgramUsage(GpuProgramType.GPT_COMPUTE_PROGRAM, this);
                    }
                    mComputeProgramUsage.setProgramName(name, resetParams);
                }
                // Needs recompilation
                mParent._notifyNeedsRecompile();
                
                if( getHashFunction() == getBuiltinHashFunction( BuiltinHashFunction.MIN_GPU_PROGRAM_CHANGE ) )
                {
                    _dirtyHash();
                }
            }
        }
    }
    /** Sets the Tesselation Evaluation program parameters.
     @remarks
     Only applicable to programmable passes.
     */
    void setComputeProgramParameters(GpuProgramParametersPtr params)
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mComputeProgramUsage)
            {
                throw new InvalidParamsError(
                    "This pass does not have a compute program assigned!",
                    "Pass.setComputeProgramParameters");
            }
            mComputeProgramUsage.setParameters(params);
        }
    }
    /** Gets the name of the Tesselation Hull program used by this pass. */
    string getComputeProgramName()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            if (!mComputeProgramUsage)
                return "";
            else
                return mComputeProgramUsage.getProgramName();
        }
    }
    /** Gets the Tesselation Hull program parameters used by this pass. */
    GpuProgramParametersPtr getComputeProgramParameters()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mComputeProgramUsage.getParameters();
        }
    }
    /** Gets the Tesselation EHull program used by this pass, only available after _load(). */
    SharedPtr!GpuProgram getComputeProgram()
    {
        synchronized(mGpuProgramChangeMutex)
        {
            return mComputeProgramUsage.getProgram();
        }
    }
}

/** Struct recording a pass which can be used for a specific illumination stage.
 @remarks
 This structure is used to record categorised passes which fit into a
 number of distinct illumination phases - ambient, diffuse / specular
 (per-light) and decal (post-lighting texturing).
 An original pass may fit into one of these categories already, or it
 may require splitting into its component parts in order to be categorised
 properly.
 */
struct IlluminationPass// : public PassAlloc
{
    IlluminationStage stage;
    /// The pass to use in this stage
    Pass pass;
    /// Whether this pass is one which should be deleted itself
    bool destroyOnShutdown;
    /// The original pass which spawned this one
    Pass originalPass;
    
    //IlluminationPass() {}
}

//typedef vector<IlluminationPass*>.type IlluminationPassList;
alias IlluminationPass[] IlluminationPassList;

/** @} */
/** @} */
