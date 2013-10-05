module ogre.rendersystem.rendersystem;

private
{
    //import std.container;
    import std.algorithm;
    import std.array;
    import std.string;
    import std.conv;
    import core.stdc.string: memcpy;
    import std.stdio;
}

import ogre.compat;
import ogre.config;
import ogre.exception;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.general.generals;
import ogre.general.log;
import ogre.image.images;
import ogre.materials.blendmode;
import ogre.materials.gpuprogram;
import ogre.materials.materialmanager;
import ogre.materials.textureunitstate;
import ogre.math.angles;
import ogre.math.frustum;
import ogre.math.matrix;
import ogre.math.plane;
import ogre.math.vector;
import ogre.rendersystem.hardware;
import ogre.rendersystem.renderoperation;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.rendertexture;
import ogre.rendersystem.renderwindow;
import ogre.rendersystem.vertex;
import ogre.rendersystem.viewport;
import ogre.resources.archive;
import ogre.resources.datastream;
import ogre.resources.texture;
import ogre.resources.texturemanager;
import ogre.scene.renderable;
import ogre.scene.scenemanager;
import ogre.sharedptr;
import ogre.singleton;
import ogre.strings;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup RenderSystem
 *  @{
 */

/**
 An object which renders geometry to a vertex.
 @remarks
 This is especially useful together with geometry shaders, as you can
 render procedural geometry which will get saved to a vertex buffer for
 reuse later, without regenerating it again. You can also create shaders
 that run on previous results of those shaders, creating stateful
 shaders.
 */
class RenderToVertexBuffer
{
public:
    /** C'tor */
    this()
    {
        mOperationType = RenderOperation.OperationType.OT_TRIANGLE_LIST;
        mResetsEveryUpdate = false;
        mResetRequested = true;
        mMaxVertexCount = 1000;
        mVertexData = new VertexData;
    }
    /** D'tor */
    ~this() { destroy(mVertexData); }

    /**
     Get the vertex declaration that the pass will output.
     @remarks
     Use this object to set the elements of the buffer. Object will calculate
     buffers on its own. Only one source allowed!
     */
    ref VertexDeclaration getVertexDeclaration()
    {
        //TODO : Mark dirty?
        return mVertexData.vertexDeclaration;
    }

    /**
     Get the maximum number of vertices that the buffer will hold
     */
    uint getMaxVertexCount(){ return mMaxVertexCount; }

    /**
     Set the maximum number of vertices that the buffer will hold
     */
    void setMaxVertexCount(uint maxVertexCount) { mMaxVertexCount = maxVertexCount; }

    /**
     What type of primitives does this object generate?
     */
    RenderOperation.OperationType getOperationType(){ return mOperationType; }

    /**
     Set the type of primitives that this object generates
     */
    void setOperationType(RenderOperation.OperationType operationType) { mOperationType = operationType; }

    /**
     Set wether this object resets its buffers each time it updates.
     */
    void setResetsEveryUpdate(bool resetsEveryUpdate) { mResetsEveryUpdate = resetsEveryUpdate; }

    /**
     Does this object reset its buffer each time it updates?
     */
    bool getResetsEveryUpdate(){ return mResetsEveryUpdate; }

    /**
     Get the render operation for this buffer
     */
    abstract void getRenderOperation(ref RenderOperation op);

    /**
     Update the contents of this vertex buffer by rendering
     */
    abstract void update(ref SceneManager sceneMgr);

    /**
     Reset the vertex buffer to the initial state. In the next update,
     the source renderable will be used as input.
     */
    void reset() { mResetRequested = true; }

    /**
     Set the source renderable of this object. During the first (and
     perhaps later) update of this object, this object's data will be
     used as input)
     */
    void setSourceRenderable(ref Renderable source) { mSourceRenderable = source; }

    /**
     Get the source renderable of this object
     */
    ref Renderable getSourceRenderable(){ return mSourceRenderable; }

    /**
     Get the material which is used to render the geometry into the
     vertex buffer.
     */
    ref SharedPtr!Material getRenderToBufferMaterial() { return mMaterial; }

    /**
     Set the material name which is used to render the geometry into
     the vertex buffer
     */
    void setRenderToBufferMaterialName(string materialName)
    {
        mMaterial = MaterialManager.getSingleton().getByName(materialName);

        if (mMaterial.isNull())
            throw new ItemNotFoundError( "Could not find material " ~ materialName,
                                        "RenderToVertexBuffer::setRenderToBufferMaterialName" );

        /* Ensure that the new material was loaded (will not load again if
         already loaded anyway)
         */
        mMaterial.getAs().load();
    }
protected:
    RenderOperation.OperationType mOperationType;
    bool mResetsEveryUpdate;
    bool mResetRequested;
    SharedPtr!Material mMaterial;
    Renderable mSourceRenderable;
    VertexData mVertexData;
    uint mMaxVertexCount;
}

//alias SharedPtr!RenderToVertexBuffer RenderToVertexBufferPtr;

/// Specialisation of HardwareVertexBuffer for emulation
class DefaultHardwareVertexBuffer :  HardwareVertexBuffer
{
protected:
    ubyte[] mData;

    /** See HardwareBuffer. */
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return /*cast(ubyte*)*/mData.ptr + offset;
    }

    /** See HardwareBuffer. */
    override void unlockImpl()
    {
        // Nothing to do
    }

public:
    this(size_t vertexSize, size_t numVertices, HardwareBuffer.Usage usage)
    {
        super(null, vertexSize, numVertices, usage, true, false); // always software, never shadowed
        // Allocate aligned memory for better SIMD processing friendly.
        mData = new ubyte[mSizeInBytes];//static_cast<ubyte*>(OGRE_MALLOC_SIMD(mSizeInBytes, MEMCATEGORY_GEOMETRY));
    }

    this(HardwareBufferManagerBase mgr, size_t vertexSize, size_t numVertices,
         HardwareBuffer.Usage usage)
    {
        super(mgr, vertexSize, numVertices, usage, true, false); // always software, never shadowed
        // Allocate aligned memory for better SIMD processing friendly.
        mData = new ubyte[mSizeInBytes];// static_cast<ubyte*>(OGRE_MALLOC_SIMD(mSizeInBytes, MEMCATEGORY_GEOMETRY));
    }

    ~this() { destroy(mData); }

    /** See HardwareBuffer. */
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }

    /** See HardwareBuffer. */
    override void writeData(size_t offset, size_t length,void* pSource,
                            bool discardWholeBuffer = false)
    {
        assert((offset + length) <= mSizeInBytes);
        // ignore discard, memory is not guaranteed to be zeroised
        memcpy(mData.ptr + offset, pSource, length);

    }

    /** Override HardwareBuffer to turn off all shadowing. */
    override void* lock(size_t offset, size_t length, LockOptions options)
    {
        mIsLocked = true;
        return mData.ptr + offset;
    }

    /** Override HardwareBuffer to turn off all shadowing. */
    override void unlock()
    {
        mIsLocked = false;
        // Nothing to do
    }

    
}

/// Specialisation of HardwareIndexBuffer for emulation
class DefaultHardwareIndexBuffer : HardwareIndexBuffer
{
protected:
    ubyte[] mData;
    /** See HardwareBuffer. */
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return mData.ptr + offset;
    }
    /** See HardwareBuffer. */
    override void unlockImpl()
    {
        // Nothing to do
    }
public:
    this(IndexType idxType, size_t numIndexes, HardwareBuffer.Usage usage)
    {
        super(null, idxType, numIndexes, usage, true, false); // always software, never shadowed
        mData = new ubyte[mSizeInBytes]; //OGRE_ALLOC_T(ubyte, mSizeInBytes, MEMCATEGORY_GEOMETRY);
    }
    ~this() { destroy(mData); }
    /** See HardwareBuffer. */
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }
    /** See HardwareBuffer. */
    override void writeData(size_t offset, size_t length,void* pSource,
                            bool discardWholeBuffer = false)
    {
        assert((offset + length) <= mSizeInBytes);
        // ignore discard, memory is not guaranteed to be zeroised
        memcpy(mData.ptr + offset, pSource, length);

    }
    /** Override HardwareBuffer to turn off all shadowing. */
    override void* lock(size_t offset, size_t length, LockOptions options)
    {
        mIsLocked = true;
        return mData.ptr + offset;
    }
    /** Override HardwareBuffer to turn off all shadowing. */
    override void unlock()
    {
        mIsLocked = false;
        // Nothing to do
    }

}

/// Specialisation of HardwareUniformBuffer for emulation
class DefaultHardwareUniformBuffer : HardwareUniformBuffer
{
protected:
    ubyte[] mData;
    /** See HardwareBuffer. */
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return mData.ptr + offset;
    }
    /** See HardwareBuffer. */
    override void unlockImpl()
    {
        // Nothing to do
    }
    /**  */
    //bool updateStructure(Any& renderSystemInfo);

public:
    this(HardwareBufferManagerBase mgr, size_t sizeBytes, HardwareBuffer.Usage usage, bool useShadowBuffer = false,string name = "")
    {
        super(mgr, sizeBytes, usage, useShadowBuffer, name);
        // Allocate aligned memory for better SIMD processing friendly.
        mData = new ubyte[mSizeInBytes]; //static_cast<ubyte*>(OGRE_MALLOC_SIMD(mSizeInBytes, MEMCATEGORY_GEOMETRY));
    }

    ~this() { destroy(mData); }

    /** See HardwareBuffer. */
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }
    /** See HardwareBuffer. */
    override void writeData(size_t offset, size_t length,void* pSource,
                            bool discardWholeBuffer = false)
    {
        assert((offset + length) <= mSizeInBytes);
        // ignore discard, memory is not guaranteed to be zeroised
        memcpy(mData.ptr + offset, pSource, length);
    }
    /** Override HardwareBuffer to turn off all shadowing. */
    override void* lock(size_t offset, size_t length, LockOptions options)
    {
        mIsLocked = true;
        return mData.ptr + offset;
    }
    /** Override HardwareBuffer to turn off all shadowing. */
    override void unlock()
    {
        mIsLocked = false;
        // Nothing to do
    }
}

/// Specialisation of HardwareCounterBuffer for emulation
class DefaultHardwareCounterBuffer : HardwareCounterBuffer
{
protected:
    ubyte[] mData;
    /** See HardwareBuffer. */
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return mData.ptr + offset;
    }
    
    /** See HardwareBuffer. */
    override void unlockImpl()
    {
        // Nothing to do
    }
    
    /**  */
    //bool updateStructure(const Any& renderSystemInfo);
    
public:
    this(HardwareBufferManagerBase mgr, size_t sizeBytes, HardwareBuffer.Usage usage, bool useShadowBuffer = false, string name = "")
    {
        super(mgr, sizeBytes, usage, useShadowBuffer, name);
        // Allocate aligned memory for better SIMD processing friendly.
        //mData = static_cast<unsigned char*>(OGRE_MALLOC_SIMD(mSizeInBytes, MEMCATEGORY_GEOMETRY));
        //TODO making this SIMD friendly
        mData = new ubyte[mSizeInBytes];
    }
    
    ~this()
    {
        destroy(mData);
    }
    
    /** See HardwareBuffer. */
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }
    
    /** See HardwareBuffer. */
    override void writeData(size_t offset, size_t length, void* pSource,
                   bool discardWholeBuffer = false)
    {
        assert((offset + length) <= mSizeInBytes);
        // ignore discard, memory is not guaranteed to be zeroised
        memcpy(mData.ptr + offset, pSource, length);
    }
    
    /** Override HardwareBuffer to turn off all shadowing. */
    override void* lock(size_t offset, size_t length, LockOptions options)
    {
        mIsLocked = true;
        return mData.ptr + offset;
    }
    
    /** Override HardwareBuffer to turn off all shadowing. */
    override void unlock()
    {
        mIsLocked = false;
        // Nothing to do
    }
}

/** Specialisation of HardwareBufferManagerBase to emulate hardware buffers.
 @remarks
 You might want to instantiate this class if you want to utilise
 classes like MeshSerializer without having initialised the
 rendering system (which is required to create a 'real' hardware
 buffer manager.
 */
class DefaultHardwareBufferManagerBase : HardwareBufferManagerBase
{
public:
    this(){}
    ~this()
    {
        destroyAllDeclarations();
        destroyAllBindings();
    }

    /// Creates a vertex buffer
    override SharedPtr!HardwareVertexBuffer
        createVertexBuffer(size_t vertexSize, size_t numVerts,
                           HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        auto vb = new DefaultHardwareVertexBuffer(this, vertexSize, numVerts, usage);
        return SharedPtr!HardwareVertexBuffer(vb);
    }

    /// Create a hardware vertex buffer
    override SharedPtr!HardwareIndexBuffer
        createIndexBuffer(HardwareIndexBuffer.IndexType itype, size_t numIndexes,
                          HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        auto ib = new DefaultHardwareIndexBuffer(itype, numIndexes, usage);
        return SharedPtr!HardwareIndexBuffer(ib);
    }

    /// Create a hardware vertex buffer
    override SharedPtr!RenderToVertexBuffer createRenderToVertexBuffer()
    {
        throw new RenderingApiError(
            "Cannot create RenderToVertexBuffer in DefaultHardwareBufferManagerBase",
            "DefaultHardwareBufferManagerBase::createRenderToVertexBuffer");
        assert(0);
    }
    /// Create a hardware uniform buffer
    override SharedPtr!HardwareUniformBuffer createUniformBuffer(size_t sizeBytes,
                                                                HardwareBuffer.Usage usage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
                                                                bool useShadowBuffer = false,string name = "")
    {
        auto ub = new DefaultHardwareUniformBuffer(this, sizeBytes, usage, useShadowBuffer);
        return SharedPtr!HardwareUniformBuffer(ub);
    }
    
    /// Create a hardware counter buffer
    override HardwareCounterBufferSharedPtr createCounterBuffer(size_t sizeBytes,
                                                       HardwareBuffer.Usage usage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
                                                       bool useShadowBuffer = false, string name = "")
    {
        DefaultHardwareCounterBuffer ub = new DefaultHardwareCounterBuffer(this, sizeBytes, usage, useShadowBuffer);
        return HardwareCounterBufferSharedPtr(ub);
    }
    
}

/// DefaultHardwareBufferManager as a Singleton
class DefaultHardwareBufferManager : HardwareBufferManager
{
public:
    this()
    {
        //assert(false, "Initialize with HardwareBufferManager.getSingleton(new DefaultHardwareBufferManagerBase());");
        //super(new DefaultHardwareBufferManagerBase());
        //HardwareBufferManager.getSingleton!(new DefaultHardwareBufferManagerBase())();
        assert(0, 
               "Don't use DefaultHardwareBufferManager.ctor directly. This only for singleton template.\n"
               "Use HardwareBufferManager.getSingletonInit!(DefaultHardwareBufferManager, mDefaultHardwareBufferManagerBase);\n"
               );
    }
    ~this()
    {
        destroy(mImpl);
    }
}


/** An abstract class that contains a depth/stencil buffer.
 Depth Buffers can be attached to render targets. Note we handle Depth & Stencil together.
 DepthBuffer sharing is handled automatically for you. However, there are times where you want
 to specifically control depth buffers to achieve certain effects or increase performance.
 You can control this by hinting Ogre with POOL IDs. Created depth buffers can live in different
 pools, or alltoghether in the same one.
 Usually, a depth buffer can only be attached to a RenderTarget only if it's dimensions are bigger
 and have the same bit depth and same multisample settings. Depth Buffers are created automatically
 for new RTs when needed, and stored in the pool where the RenderTarget should have drawn from.
 By default, all RTs have the Id POOL_DEFAULT, which means all depth buffers are stored by default
 in that pool. By chosing a different Pool Id for a specific RenderTarget, that RT will only
 retrieve depth buffers from _that_ pool, Therefore not conflicting with sharing depth buffers
 with other RTs (such as shadows maps).
 Setting an RT to POOL_MANUAL_USAGE means Ogre won't manage the DepthBuffer for you (not recommended)
 RTs with POOL_NO_DEPTH are very useful when you don't want to create a DepthBuffer for it. You can
 still manually attach a depth buffer though as internally POOL_NO_DEPTH & POOL_MANUAL_USAGE are
 handled in the same way.

 Behavior is consistent across all render systems, if, and only if, the same RSC flags are set
 RSC flags that affect this class are:
 * RSC_RTT_SEPARATE_DEPTHBUFFER:
 The RTT can create a custom depth buffer different from the main depth buffer. This means,
 an RTT is able to not share it's depth buffer with the main window if it wants to.
 * RSC_RTT_MAIN_DEPTHBUFFER_ATTACHABLE:
 When RSC_RTT_SEPARATE_DEPTHBUFFER is set, some APIs (ie. OpenGL w/ FBO) don't allow using
 the main depth buffer for offscreen RTTs. When this flag is set, the depth buffer can be
 shared between the main window and an RTT.
 * RSC_RTT_DEPTHBUFFER_RESOLUTION_LESSEQUAL:
 When this flag isn't set, the depth buffer can only be shared across RTTs who have the EXACT
 same resolution. When it's set, it can be shared with RTTs as long as they have a
 resolution less or equal than the depth buffer's.

 @remarks
 Design discussion http://www.ogre3d.org/forums/viewtopic.php?f=4&t=53534&p=365582
 @author
 Matias N. Goldberg
 @version
 1.0
 */
class DepthBuffer //: public RenderSysAlloc
{
public:
    enum PoolId
    {
        POOL_NO_DEPTH       = 0,
        POOL_MANUAL_USAGE   = 0,
        POOL_DEFAULT        = 1
    }
    
    this( ushort poolId, ushort bitDepth, uint width, uint height,
         uint fsaa,string fsaaHint, bool manual )
    {
        mPoolId = poolId;
        mBitDepth = bitDepth;
        mWidth = width;
        mHeight = height;
        mFsaa = fsaa;
        mFsaaHint = fsaaHint;
        mManual = manual;
    }

    ~this()
    {
        detachFromAllRenderTargets();
    }
    
    //Sets the pool id in which this DepthBuffer lives
    //Note this will detach any render target from this depth buffer
    void _setPoolId( ushort poolId )
    {
        //Change the pool Id
        mPoolId = poolId;
        
        //Render Targets were attached to us, but they have a different pool Id,
        //so detach ourselves from them
        detachFromAllRenderTargets();
    }
    
    //Gets the pool id in which this DepthBuffer lives
    ushort getPoolId() const
    {
        return mPoolId;
    }
    ushort getBitDepth() const
    {
        return mBitDepth;
    }
    uint getWidth() const
    {
        return mWidth;
    }
    uint getHeight() const
    {
        return mHeight;
    }
    uint getFsaa() const
    {
        return mFsaa;
    }
    string getFsaaHint()
    {
        return mFsaaHint;
    }
    
    //Manual DepthBuffers are cleared in RenderSystem's destructor. Non-manual ones are released
    //with it's render target (aka, a backbuffer or similar)
    bool isManual()
    {
        return mManual;
    }
    
    /** Returns whether the specified RenderTarget is compatible with this DepthBuffer
     That is, this DepthBuffer can be attached to that RenderTarget
     @remarks
     Most APIs impose the following restrictions:
     Width & height must be equal or higher than the render target's
     They must be of the same bit depth.
     They need to have the same FSAA setting
     @param renderTarget The render target to test against
     */
    bool isCompatible( RenderTarget renderTarget )// const
    {
        if( this.getWidth() >= renderTarget.getWidth() &&
           this.getHeight() >= renderTarget.getHeight() &&
           this.getFsaa() == renderTarget.getFSAA() )
        {
            return true;
        }
        
        return false;
    }
    
    /** Called when a RenderTarget is attaches this DepthBuffer
     @remarks
     This function doesn't actually attach. It merely informs the DepthBuffer
     which RenderTarget did attach. The real attachment happens in
     RenderTarget::attachDepthBuffer()
     @param renderTarget The RenderTarget that has just been attached
     */
    void _notifyRenderTargetAttached( ref RenderTarget renderTarget )
    {
        assert( mAttachedRenderTargets[].find( renderTarget ).empty );
        
        mAttachedRenderTargets.insert( renderTarget );
    }
    
    /** Called when a RenderTarget is detaches from this DepthBuffer
     @remarks
     Same as DepthBuffer::_notifyRenderTargetAttached()
     @param renderTarget The RenderTarget that has just been attached
     */
    void _notifyRenderTargetDetached( ref RenderTarget renderTarget )
    {
        mAttachedRenderTargets.removeFromArray(renderTarget);
    }
    
protected:
    //typedef set<RenderTarget*>::type RenderTargetSet;
    alias RenderTarget[] RenderTargetSet;
    
    ushort                      mPoolId;
    ushort                      mBitDepth;
    uint                      mWidth;
    uint                      mHeight;
    uint                      mFsaa;
    string                      mFsaaHint;
    
    bool                        mManual; //We don't Release manual surfaces on destruction
    RenderTargetSet             mAttachedRenderTargets;
    
    void detachFromAllRenderTargets()
    {
        foreach(itor; mAttachedRenderTargets)
        //while(mAttachedRenderTargets.length > 0)
        {
            //TODO Check if removed in _notifyRenderTargetDetached
            //If we call, detachDepthBuffer, we'll invalidate the iterators
            itor._detachDepthBuffer();
        }
        
        mAttachedRenderTargets.clear();
    }
}


//typedef vector<DepthBuffer*>::type DepthBufferVec;
//typedef map< ushort, DepthBufferVec >::type DepthBufferMap;
//typedef map< String, RenderTarget * >::type RenderTargetMap;
//typedef multimap<uchar, RenderTarget * >::type RenderTargetPriorityMap;

alias DepthBuffer[]    DepthBufferVec;
alias DepthBufferVec[uint] DepthBufferMap;
alias RenderTarget[string] RenderTargetMap;
//alias MultiMap!(ubyte, RenderTarget) RenderTargetPriorityMap;
alias RenderTarget[][ubyte] RenderTargetPriorityMap;

/// Enum describing the ways to generate texture coordinates
enum TexCoordCalcMethod
{
    /// No calculated texture coordinates
    TEXCALC_NONE,
    /// Environment map based on vertex normals
    TEXCALC_ENVIRONMENT_MAP,
    /// Environment map based on vertex positions
    TEXCALC_ENVIRONMENT_MAP_PLANAR,
    TEXCALC_ENVIRONMENT_MAP_REFLECTION,
    TEXCALC_ENVIRONMENT_MAP_NORMAL,
    /// Projective texture
    TEXCALC_PROJECTIVE_TEXTURE
}

/// Enum describing the various actions which can be taken onthe stencil buffer
enum StencilOperation
{
    /// Leave the stencil buffer unchanged
    SOP_KEEP,
    /// Set the stencil value to zero
    SOP_ZERO,
    /// Set the stencil value to the reference value
    SOP_REPLACE,
    /// Increase the stencil value by 1, clamping at the maximum value
    SOP_INCREMENT,
    /// Decrease the stencil value by 1, clamping at 0
    SOP_DECREMENT,
    /// Increase the stencil value by 1, wrapping back to 0 when incrementing the maximum value
    SOP_INCREMENT_WRAP,
    /// Decrease the stencil value by 1, wrapping when decrementing 0
    SOP_DECREMENT_WRAP,
    /// Invert the bits of the stencil buffer
    SOP_INVERT
}


/** Defines the functionality of a 3D API
 @remarks
 The RenderSystem class provides a base interface
 which abstracts the general functionality of the 3D API
 e.g. Direct3D or OpenGL. Whilst a few of the general
 methods have implementations, most of this class is
 abstract, requiring a subclass based on a specific API
 to beructed to provide the full functionality.
 Note there are 2 levels to the interface - one which
 will be used often by the caller of the Ogre library,
 and one which is at a lower level and will be used by the
 other classes provided by Ogre. These lower level
 methods are prefixed with '_' to differentiate them.
 The advanced user of the library may use these lower
 level methods to access the 3D API at a more fundamental
 level (dealing direct with render states and rendering
 primitives), but still benefiting from Ogre's abstraction
 of exactly which 3D API is in use.
 @author
 Steven Streeting
 @version
 1.0
 */
//TODO D can't do shared libraries yet? :(
//NOTE https://github.com/alexrp/druntime/commit/80f993025928ab2a0b79c3f5ed0a7b388743c7ae
class RenderSystem //: public RenderSysAlloc
{
public:
    //static const (SharedPtr!Texture) sNullTexPtr;
    static SharedPtr!Texture sNullTexPtr;
    /*static this()
    {
        sNullTexPtr = SharedPtr!Texture();
    }*/

    /** Default Constructor.
     */
    this()
    {
        //mActiveRenderTarget = null;
        //mTextureManager = null;
        //mActiveViewport = null;
        // This means CULL clockwise vertices i.e. front of poly is counter-clockwise
        // This makes it the same as OpenGL and other right-handed systems
        mCullingMode = CullingMode.CULL_CLOCKWISE;
        mVSync = true;
        mVSyncInterval = 1;
        mWBuffer = false;
        mInvertVertexWinding = false;
        mDisabledTexUnitsFrom = 0;
        mCurrentPassIterationCount = 0;
        mCurrentPassIterationNum = 0;
        mDerivedDepthBias = false;
        mDerivedDepthBiasBase = 0.0f;
        mDerivedDepthBiasMultiplier = 0.0f;
        mDerivedDepthBiasSlopeScale = 0.0f;
        mGlobalInstanceVertexBufferVertexDeclaration = null;
        mGlobalNumberOfInstances = 1;

        static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)//TODO Versions
        {
            mEnableFixedPipeline = true;
        }
        mGeometryProgramBound = false;
        mFragmentProgramBound = false;
        mTesselationHullProgramBound = false;
        mTesselationDomainProgramBound = false;
        mComputeProgramBound = false;
        mClipPlanesDirty = true;
        mRealCapabilities = null;
        mCurrentCapabilities = null;
        mUseCustomCapabilities = false;
        mTexProjRelative = false;
        mTexProjRelativeOrigin = Vector3.ZERO;

        mEventNames.insert("RenderSystemCapabilitiesCreated");
    }

    /** Destructor.
     */
    ~this()
    {
        shutdown();
        destroy(mRealCapabilities);
        mRealCapabilities = null;
        // Current capabilities managed externally
        mCurrentCapabilities = null;
    }

    /** Returns the name of the rendering system.
     */
    abstract string getName();

    /** Returns the details of this API's configuration options
     @remarks
     Each render system must be able to inform the world
     of what options must/can be specified for it's
     operation.
     @par
     These are passed as strings for portability, but
     grouped into a structure (_ConfigOption) which includes
     both options and current value.
     @par
     Note that the settings returned from this call are
     affected by the options that have been set so far,
     since some options are interdependent.
     @par
     This routine is called automatically by the default
     configuration dialogue produced by Root::showConfigDialog
     or may be used by the caller for custom settings dialogs
     @return
     A 'map' of options, i.e. a list of options which is also
     indexed by option name.
     */
    abstract ConfigOptionMap getConfigOptions();

    /** Sets an option for this API
     @remarks
     Used to confirm the settings (normally chosen by the user) in
     order to make the renderer able to initialise with the settings as required.
     This may be video mode, D3D driver, full screen / windowed etc.
     Called automatically by the default configuration
     dialog, and by the restoration of saved settings.
     These settings are stored and only activated when
     RenderSystem::initialise or RenderSystem::reinitialise
     are called.
     @par
     If using a custom configuration dialog, it is advised that the
     caller calls RenderSystem::getConfigOptions
     again, since some options can alter resulting from a selection.
     @param
     name The name of the option to alter.
     @param
     value The value to set the option to.
     */
    abstract void setConfigOption(string name,string value);

    /** Create an object for performing hardware occlusion queries.
     */
    abstract HardwareOcclusionQuery createHardwareOcclusionQuery();

    /** Destroy a hardware occlusion query object.
     */
    void destroyHardwareOcclusionQuery(ref HardwareOcclusionQuery hq)
    {
        mHwOcclusionQueries.removeFromArray(hq);
        destroy(hq);
    }

    /** Validates the options set for the rendering system, returning a message if there are problems.
     @note
     If the returned string is empty, there are no problems.
     */
    abstract string validateConfigOptions();

    /** Start up the renderer using the settings selected (Or the defaults if none have been selected).
     @remarks
     Called by Root::setRenderSystem. Shouldn't really be called
     directly, although  this can be done if the app wants to.
     @param
     autoCreateWindow If true, creates a render window
     automatically, based on settings chosen so far. This saves
     an extra call to _createRenderWindow
     for the main render window.
     @param
     windowTitle Sets the app window title
     @return
     A pointer to the automatically created window, if requested, otherwise null.
     */
    RenderWindow _initialise(bool autoCreateWindow,string windowTitle = "OGRE Render Window")
    {
        // Have I been registered by call to Root::setRenderSystem?
        /** Don't do this anymore, just allow via Root
         RenderSystem* regPtr = Root::getSingleton().getRenderSystem();
         if (!regPtr || regPtr != this)
         // Register self - library user has come to me direct
         Root::getSingleton().setRenderSystem(this);
         */

        
        // Subclasses should take it from here
        // They should ALL call this superclass method from
        //   their own initialise() implementations.

        mVertexProgramBound = false;
        mGeometryProgramBound = false;
        mFragmentProgramBound = false;
        mTesselationHullProgramBound = false;
        mTesselationDomainProgramBound = false;
        mComputeProgramBound = false;

        return null;
    }

    /*
     Returns whether under the current render system buffers marked as TU_STATIC can be locked for update
     @remarks
     Needed in the implementation of DirectX9 with DirectX9Ex driver
     */
    bool isStaticBufferLockable(){ return true; }

    /** Query the real capabilities of the GPU and driver in the RenderSystem*/
    abstract RenderSystemCapabilities createRenderSystemCapabilities();

    /** Get a pointer to the current capabilities being used by the RenderSystem.
     @remarks
     The capabilities may be modified using this pointer, this will only have an effect
     before the RenderSystem has been initialised. It's intended use is to allow a
     listener of the RenderSystemCapabilitiesCreated event to customise the capabilities
     on the fly before the RenderSystem is initialised.
     */
    ref RenderSystemCapabilities getMutableCapabilities(){ return mCurrentCapabilities; }

    /** Force the render system to use the special capabilities. Can only be called
     *    before the render system has been fully initializer (before createWindow is called)
     *   @param
     *        capabilities has to be a subset of the real capabilities and the caller is
     *        responsible for deallocating capabilities.
     */
    void useCustomRenderSystemCapabilities(ref RenderSystemCapabilities capabilities)
    {
        if (mRealCapabilities !is null)
        {
            throw new InternalError(
                "Custom render capabilities must be set before the RenderSystem is initialised.",
                "RenderSystem.useCustomRenderSystemCapabilities");
        }

        mCurrentCapabilities = capabilities;
        mUseCustomCapabilities = true;
    }

    /** Restart the renderer (normally following a change in settings).
     */
    abstract void reinitialise();

    /** Shutdown the renderer and cleanup resources.
     */
    void shutdown()
    {
        // Remove occlusion queries
        foreach (i; mHwOcclusionQueries)
        {
            destroy(i);
        }
        mHwOcclusionQueries.clear();

        _cleanupDepthBuffers();

        // Remove all the render targets.
        // (destroy primary target last since others may depend on it)
        RenderTarget primary = null;
        foreach (k,v; mRenderTargets)
        {
            if (!primary && v.isPrimary())
                primary = v;
            else
                destroy(v);
        }
        destroy(primary); //TODO null this assert?
        mRenderTargets.clear();

        mPrioritisedRenderTargets.clear();
    }

    
    /** Sets the colour & strength of the ambient (global directionless) light in the world.
     */
    abstract void setAmbientLight(float r, float g, float b);

    /** Sets the type of light shading required (default = Gouraud).
     */
    abstract void setShadingType(ShadeOptions so);

    /** Sets whether or not dynamic lighting is enabled.
     @param
     enabled If true, dynamic lighting is performed on geometry with normals supplied, geometry without
     normals will not be displayed. If false, no lighting is applied and all geometry will be full brightness.
     */
    abstract void setLightingEnabled(bool enabled);

    /** Sets whether or not W-buffers are enabled if they are available for this renderer.
     @param
     enabled If true and the renderer supports them W-buffers will be used.  If false
     W-buffers will not be used even if available.  W-buffers are enabled by default
     for 16bit depth buffers and disabled for all other depths.
     */
    void setWBufferEnabled(bool enabled)
    {
        mWBuffer = enabled;
    }

    /** Returns true if the renderer will try to use W-buffers when avalible.
     */
    bool getWBufferEnabled()
    {
        return mWBuffer;
    }

    /** Creates a new rendering window.
     @remarks
     This method creates a new rendering window as specified
     by the paramteters. The rendering system could be
     responible for only a single window (e.g. in the case
     of a game), or could be in charge of multiple ones (in the
     case of a level editor). The option to create the window
     as a child of another is Therefore given.
     This method will create an appropriate subclass of
     RenderWindow depending on the API and platform implementation.
     @par
     After creation, this window can be retrieved using getRenderTarget().
     @param
     name The name of the window. Used in other methods
     later like setRenderTarget and getRenderTarget.
     @param
     width The width of the new window.
     @param
     height The height of the new window.
     @param
     fullScreen Specify true to make the window full screen
     without borders, title bar or menu bar.
     @param
     miscParams A NameValuePairList describing the other parameters for the new rendering window.
     Options are case sensitive. Unrecognised parameters will be ignored silently.
     These values might be platform dependent, but these are present for all platforms unless
     indicated otherwise:
     <table>
     <tr>
     <td><b>Key</b></td>
     <td><b>Type/Values</b></td>
     <td><b>Default</b></td>
     <td><b>Description</b></td>
     <td><b>Notes</b></td>
     </tr>
     <tr>
     <td>title</td>
     <td>Any string</td>
     <td>RenderTarget name</td>
     <td>The title of the window that will appear in the title bar</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>colourDepth</td>
     <td>16, 32</td>
     <td>Desktop depth</td>
     <td>Colour depth of the resulting rendering window; only applies if fullScreen</td>
     <td>Win32 Specific</td>
     </tr>
     <tr>
     <td>left</td>
     <td>Positive integers</td>
     <td>Centred</td>
     <td>Screen x coordinate from left</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>top</td>
     <td>Positive integers</td>
     <td>Centred</td>
     <td>Screen y coordinate from left</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>depthBuffer</td>
     <td>true, false</td>
     <td>true</td>
     <td>Use depth buffer</td>
     <td>DirectX9 specific</td>
     </tr>
     <tr>
     <td>externalWindowHandle</td>
     <td>Win32: HWND as integer<br/>
     GLX: poslong:posint:poslong (display*:screen:windowHandle) or poslong:posint:poslong:poslong (display*:screen:windowHandle:XVisualInfo*)<br/>
     OS X: WindowRef for Carbon or NSWindow for Cocoa address as an integer
     iOS: UIWindow address as an integer
     </td>
     <td>0 (none)</td>
     <td>External window handle, for embedding the OGRE render in an existing window</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>externalGLControl</td>
     <td>true, false</td>
     <td>false</td>
     <td>Let the external window control OpenGL i.e. don't select a pixel format for the window,
     do not change v-sync and do not swap buffer. When set to true, the calling application
     is responsible of OpenGL initialization and buffer swapping. It should also create an
     OpenGL context for its own rendering, Ogre will create one for its use. Then the calling
     application must also enable Ogre OpenGL context before calling any Ogre function and
     restore its OpenGL context after these calls.</td>
     <td>OpenGL specific</td>
     </tr>
     <tr>
     <td>externalGLContext</td>
     <td>Context as ulong</td>
     <td>0 (create own context)</td>
     <td>Use an externally created GL context</td>
     <td>OpenGL Specific</td>
     </tr>
     <tr>
     <td>parentWindowHandle</td>
     <td>Win32: HWND as integer<br/>
     GLX: poslong:posint:poslong (display*:screen:windowHandle) or poslong:posint:poslong:poslong (display*:screen:windowHandle:XVisualInfo*)</td>
     <td>0 (none)</td>
     <td>Parent window handle, for embedding the OGRE in a child of an external window</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>macAPI</td>
     <td>String: "cocoa" or "carbon"</td>
     <td>"carbon"</td>
     <td>Specifies the type of rendering window on the Mac Platform.</td>
     <td>Mac OS X Specific</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>macAPICocoaUseNSView</td>
     <td>bool "true" or "false"</td>
     <td>"false"</td>
     <td>On the Mac platform the most diffused method to embed OGRE in a custom application is to use Interface Builder
     and add to the interface an instance of OgreView.
     The pointer to this instance is then used as "externalWindowHandle".
     However, there are cases where you are NOT using Interface Builder and you get the Cocoa NSView* of an existing interface.
     For example, this is happens when you want to render into a Java/AWT interface.
     In short, by setting this flag to "true" the Ogre::Root::createRenderWindow interprets the "externalWindowHandle" as a NSView*
     instead of an OgreView*. See OgreOSXCocoaView.h/mm.
     </td>
     <td>Mac OS X Specific</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>contentScalingFactor</td>
     <td>Positive Float greater than 1.0</td>
     <td>The default content scaling factor of the screen</td>
     <td>Specifies the CAEAGLLayer content scaling factor.  Only supported on iOS 4 or greater.
     This can be useful to limit the resolution of the OpenGL ES backing store.  For example, the iPhone 4's
     native resolution is 960 x 640.  Windows are always 320 x 480, if you would like to limit the display
     to 720 x 480, specify 1.5 as the scaling factor.
     </td>
     <td>iOS Specific</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>externalViewHandle</td>
     <td>UIView pointer as an integer</td>
     <td>0</td>
     <td>External view handle, for rendering OGRE render in an existing view</td>
     <td>iOS Specific</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>externalViewControllerHandle</td>
     <td>UIViewController pointer as an integer</td>
     <td>0</td>
     <td>External view controller handle, for embedding OGRE in an existing view controller</td>
     <td>iOS Specific</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>FSAA</td>
     <td>Positive integer (usually 0, 2, 4, 8, 16)</td>
     <td>0</td>
     <td>Full screen antialiasing factor</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>FSAAHint</td>
     <td>Depends on RenderSystem and hardware. Currently supports:<br/>
     "Quality": on systems that have an option to prefer higher AA quality over speed, use it</td>
     <td>Blank</td>
     <td>Full screen antialiasing hint</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>displayFrequency</td>
     <td>Refresh rate in Hertz (e.g. 60, 75, 100)</td>
     <td>Desktop vsync rate</td>
     <td>Display frequency rate, for fullscreen mode</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>vsync</td>
     <td>true, false</td>
     <td>false</td>
     <td>Synchronize buffer swaps to monitor vsync, eliminating tearing at the expense of a fixed frame rate</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>vsyncInterval</td>
     <td>1, 2, 3, 4</td>
     <td>1</td>
     <td>If vsync is enabled, the minimum number of vertical blanks that should occur between renders.
     For example if vsync is enabled, the refresh rate is 60 and this is set to 2, then the
     frame rate will be locked at 30.</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>border</td>
     <td>none, fixed, resize</td>
     <td>resize</td>
     <td>The type of window border (in windowed mode)</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>outerDimensions</td>
     <td>true, false</td>
     <td>false</td>
     <td>Whether the width/height is expressed as the size of the
     outer window, rather than the content area</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>useNVPerfHUD</td>
     <td>true, false</td>
     <td>false</td>
     <td>Enable the use of nVidia NVPerfHUD</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>gamma</td>
     <td>true, false</td>
     <td>false</td>
     <td>Enable hardware conversion from linear colour space to gamma
     colour space on rendering to the window.</td>
     <td>&nbsp;</td>
     </tr>
     <tr>
     <td>enableDoubleClick</td>
     <td>true, false</td>
     <td>false</td>
     <td>Enable the window to keep track and transmit double click messages.</td>
     <td>Win32 Specific</td>
     </tr>

     */
    abstract RenderWindow _createRenderWindow(string name, uint width, uint height,
                                              bool fullScreen,NameValuePairList miscParams = NameValuePairList.init);

    /** Creates multiple rendering windows.
     @param
     renderWindowDescriptions Array of structures containing the descriptions of each render window.
     The structure's members are the same as the parameters of _createRenderWindow:
     * name
     * width
     * height
     * fullScreen
     * miscParams
     See _createRenderWindow for details about each member.
     @param
     createdWindows This array will hold the created render windows.
     @return
     true on success.
     */
    bool _createRenderWindows(const(RenderWindowDescriptionList) renderWindowDescriptions,
                              RenderWindowList createdWindows)
    {
        uint fullscreenWindowsCount = 0;

        // Grab some information and avoid duplicate render windows.
        foreach (nWindow; 0..renderWindowDescriptions.length)
        {
            const(RenderWindowDescription) curDesc = renderWindowDescriptions[nWindow];

            // Count full screen windows.
            if (curDesc.useFullScreen)
                fullscreenWindowsCount++;

            bool renderWindowFound = false;

            if ( (curDesc.name in mRenderTargets) !is null)
                renderWindowFound = true;
            else
            {
                foreach (nSecWindow; nWindow + 1 .. renderWindowDescriptions.length)
                {
                    if (curDesc.name == renderWindowDescriptions[nSecWindow].name)
                    {
                        renderWindowFound = true;
                        break;
                    }
                }
            }

            // Make sure we don't already have a render target of the
            // same name as the one supplied
            if(renderWindowFound)
            {
                string msg = "A render target of the same name '" ~ curDesc.name ~ "' already " ~
                    "exists.  You cannot create a new window with this name.";
                throw new InternalError( msg, "RenderSystem.createRenderWindow" );
            }
        }

        // Case we have to create some full screen rendering windows.
        if (fullscreenWindowsCount > 0)
        {
            // Can not mix full screen and windowed rendering windows.
            if (fullscreenWindowsCount != renderWindowDescriptions.length)
            {
                throw new InvalidParamsError(
                    "Can not create mix of full screen and windowed rendering windows",
                    "RenderSystem.createRenderWindows");
            }
        }

        return true;
    }

    
    /** Create a MultiRenderTarget, which is a render target that renders to multiple RenderTextures
     at once. Surfaces can be bound and unbound at will.
     This fails if mCapabilities.getNumMultiRenderTargets() is smaller than 2.
     */
    abstract MultiRenderTarget createMultiRenderTarget(string name);

    /** Destroys a render window */
    void destroyRenderWindow(string name)
    {
        destroyRenderTarget(name);
    }

    /** Destroys a render texture */
    void destroyRenderTexture(string name)
    {
        destroyRenderTarget(name);
    }

    /** Destroys a render target of any sort */
    void destroyRenderTarget(string name)
    {
        RenderTarget rt = detachRenderTarget(name);
        destroy(rt);
    }

    /** Attaches the passed render target to the render system.
     */
    void attachRenderTarget( RenderTarget target )
    {
        assert( target.getPriority() < OGRE_NUM_RENDERTARGET_GROUPS );

        mRenderTargets[target.getName()] = target;
        mPrioritisedRenderTargets.initAA(target.getPriority());
        mPrioritisedRenderTargets[target.getPriority()] ~= target;
    }

    /** Returns a pointer to the render target with the passed name, or NULL if that
     render target cannot be found.
     */
    RenderTarget getRenderTarget(string name )
    {
        auto it = name in mRenderTargets;
        RenderTarget ret = null;

        if( it !is null)
        {
            ret = *it;
        }

        return ret;
    }
    /** Detaches the render target with the passed name from the render system and
     returns a pointer to it.
     @note
     If the render target cannot be found, NULL is returned.
     */
    RenderTarget detachRenderTarget(string name )
    {
        auto it = name in mRenderTargets;
        RenderTarget ret = null;

        if( it !is null)
        {
            ret = *it;

            /* Remove the render target from the priority groups. */
            foreach(k,vs; mPrioritisedRenderTargets)
            {
                foreach(v; vs)
                if( v == ret ) {
                    mPrioritisedRenderTargets.remove( k );
                    break;
                }
            }

            mRenderTargets.remove( name );
        }
        /// If detached render target is the active render target, reset active render target
        if(ret == mActiveRenderTarget)
            mActiveRenderTarget = null;

        return ret;
    }

    /// Iterator over RenderTargets
    //typedef MapIterator<Ogre::RenderTargetMap> RenderTargetIterator;

    /** Returns a specialised MapIterator over all render targets attached to the RenderSystem. */
    //RenderTargetIterator getRenderTargetIterator() {
    //    return RenderTargetIterator( mRenderTargets.begin(), mRenderTargets.end() );
    //}
    RenderTargetMap getRenderTargets()
    {
        return mRenderTargets;
    }

    /** Returns a description of an error code.
     */
    abstract string getErrorDescription(long errorNumber);

    /** Defines whether or now fullscreen render windows wait for the vertical blank before flipping buffers.
     @remarks
     By default, all rendering windows wait for a vertical blank (when the CRT beam turns off briefly to move
     from the bottom right of the screen back to the top left) before flipping the screen buffers. This ensures
     that the image you see on the screen is steady. However it restricts the frame rate to the refresh rate of
     the monitor, and can slow the frame rate down. You can speed this up by not waiting for the blank, but
     this has the downside of introducing 'tearing' artefacts where part of the previous frame is still displayed
     as the buffers are switched. Speed vs quality, you choose.
     @note
     Has NO effect on windowed mode render targets. Only affects fullscreen mode.
     @param
     enabled If true, the system waits for vertical blanks - quality over speed. If false it doesn't - speed over quality.
     */
    void setWaitForVerticalBlank(bool enabled)
    {
        mVSync = enabled;
    }

    /** Returns true if the system is synchronising frames with the monitor vertical blank.
     */
    bool getWaitForVerticalBlank()
    {
        return mVSync;
    }

    /** Returns the global instance vertex buffer.
     */
    SharedPtr!HardwareVertexBuffer getGlobalInstanceVertexBuffer()
    {
        return mGlobalInstanceVertexBuffer;
    }

    /** Sets the global instance vertex buffer.
     */
    void setGlobalInstanceVertexBuffer(SharedPtr!HardwareVertexBuffer val)
    {
        if ( !val.isNull() && !val.get().getIsInstanceData() )
        {
            throw new InvalidParamsError(
                "A none instance data vertex buffer was set to be the global instance vertex buffer.",
                "RenderSystem.setGlobalInstanceVertexBuffer");
        }
        mGlobalInstanceVertexBuffer = val;
    }
    /** Gets vertex declaration for the global vertex buffer for the global instancing
     */
    ref VertexDeclaration getGlobalInstanceVertexBufferVertexDeclaration()
    {
        return mGlobalInstanceVertexBufferVertexDeclaration;
    }
    /** Sets vertex declaration for the global vertex buffer for the global instancing
     */
    void setGlobalInstanceVertexBufferVertexDeclaration( ref VertexDeclaration val)
    {
        mGlobalInstanceVertexBufferVertexDeclaration = val;
    }
    /** Gets the global number of instances.
     */
    size_t getGlobalNumberOfInstances()
    {
        return mGlobalNumberOfInstances;
    }
    /** Sets the global number of instances.
     */
    void setGlobalNumberOfInstances(size_t val)
    {
        mGlobalNumberOfInstances = val;
    }

    static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
    {
        /** Sets if fixed pipeline rendering is enabled on the system.
         */
        void setFixedPipelineEnabled(bool enabled)
        {
            mEnableFixedPipeline = enabled;
        }

        /** Returns true if fixed pipeline rendering is enabled on the system.
         */
        bool getFixedPipelineEnabled()
        {
            return mEnableFixedPipeline;
        }
    }

    /** Retrieves an existing DepthBuffer or creates a new one suited for the given RenderTarget
     and sets it.
     @remarks
     RenderTarget's pool ID is respected. @see RenderTarget::setDepthBufferPool()
     */
    void setDepthBufferFor( ref RenderTarget renderTarget )
    {
        ushort poolId = renderTarget.getDepthBufferPool();
        if( poolId == DepthBuffer.PoolId.POOL_NO_DEPTH )
            return; //RenderTarget explicitly requested no depth buffer

        //Find a depth buffer in the pool
        bool bAttached = false;
        //while( itor != end && !bAttached )
        foreach(i; mDepthBufferPool[poolId])
        {
            bAttached = renderTarget.attachDepthBuffer( i );
            if(bAttached) break;
        }

        //Not found yet? Create a new one!
        if( !bAttached )
        {
            DepthBuffer newDepthBuffer = _createDepthBufferFor( renderTarget );

            if( newDepthBuffer )
            {
                newDepthBuffer._setPoolId( poolId );
                mDepthBufferPool[poolId].insert( newDepthBuffer );

                bAttached = renderTarget.attachDepthBuffer( newDepthBuffer );

                assert( bAttached, "A new DepthBuffer for a RenderTarget was created, but after creation" ~
                       "it says it's incompatible with that RT" );
            }
            else
                LogManager.getSingleton().logMessage( "WARNING: Couldn't create a suited DepthBuffer" ~
                                                     "for RT: " ~ renderTarget.getName() );
        }
    }

    // ------------------------------------------------------------------------
    //                     Internal Rendering Access
    // All methods below here are normally only called by other OGRE classes
    // They can be called by library user if required
    // ------------------------------------------------------------------------

    
    /** Tells the rendersystem to use the attached set of lights (and no others)
     up to the number specified (this allows the same list to be used with different
     count limits) */
    abstract void _useLights(LightList lights, ushort limit);
    /** Are fixed-function lights provided in view space? Affects optimisation.
     */
    bool areFixedFunctionLightsInViewSpace(){ return false; }
    /** Sets the world transform matrix. */
    abstract void _setWorldMatrix(Matrix4 m);
    /** Sets multiple world matrices (vertex blending). */
    void _setWorldMatrices(Matrix4[] m, ushort count)
    {
        // Do nothing with these matrices here, it never used for now,
        // derived class should take care with them if required.

        // Set hardware matrix to nothing
        _setWorldMatrix(Matrix4.IDENTITY);
    }
    /** Sets the view transform matrix */
    abstract void _setViewMatrix(Matrix4 m);
    /** Sets the projection transform matrix */
    abstract void _setProjectionMatrix(const(Matrix4) m);
    /** Utility function for setting all the properties of a texture unit at once.
     This method is also worth using over the individual texture unit settings because it
     only sets those settings which are different from the current settings for this
     unit, thus minimising render state changes.
     */
    void _setTextureUnitSettings(size_t texUnit, ref TextureUnitState tl)
    {
        // This method is only ever called to set a texture unit to valid details
        // The method _disableTextureUnit is called to turn a unit off

        SharedPtr!Texture tex = tl._getTexturePtr();
        // Vertex texture binding?
        if (mCurrentCapabilities.hasCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH) &&
            !mCurrentCapabilities.getVertexTextureUnitsShared())
        {
            if (tl.getBindingType() == TextureUnitState.BindingType.BT_VERTEX)
            {
                // Bind vertex texture
                _setVertexTexture(texUnit, tex);
                // bind nothing to fragment unit (hardware isn't shared but fragment
                // unit can't be using the same index
                _setTexture(texUnit, true, sNullTexPtr);
            }
            else
            {
                // vice versa
                _setVertexTexture(texUnit, sNullTexPtr);
                _setTexture(texUnit, true, tex);
            }
        }
        else
        {
            // Shared vertex / fragment textures or no vertex texture support
            // Bind texture (may be blank)
            _setTexture(texUnit, true, tex);
        }

        // Set texture coordinate set
        _setTextureCoordSet(texUnit, tl.getTextureCoordSet());

        //Set texture layer compare state and function
        _setTextureUnitCompareEnabled(texUnit,tl.getTextureCompareEnabled());
        _setTextureUnitCompareFunction(texUnit,tl.getTextureCompareFunction());

        
        // Set texture layer filtering
        _setTextureUnitFiltering(texUnit,
                                 tl.getTextureFiltering(FilterType.FT_MIN),
                                 tl.getTextureFiltering(FilterType.FT_MAG),
                                 tl.getTextureFiltering(FilterType.FT_MIP));

        // Set texture layer filtering
        _setTextureLayerAnisotropy(texUnit, tl.getTextureAnisotropy());

        // Set mipmap biasing
        _setTextureMipmapBias(texUnit, tl.getTextureMipmapBias());

        // Set blend modes
        // Note, colour before alpha is important
        _setTextureBlendMode(texUnit, tl.getColourBlendMode());
        _setTextureBlendMode(texUnit, tl.getAlphaBlendMode());

        // Texture addressing mode
        TextureUnitState.UVWAddressingMode uvw = tl.getTextureAddressingMode();
        _setTextureAddressingMode(texUnit, uvw);
        // Set texture border colour only if required
        if (uvw.u == TextureUnitState.TAM_BORDER ||
            uvw.v == TextureUnitState.TAM_BORDER ||
            uvw.w == TextureUnitState.TAM_BORDER)
        {
            _setTextureBorderColour(texUnit, tl.getTextureBorderColour());
        }

        // Set texture effects
        // Iterate over new effects
        bool anyCalcs = false;
        foreach (k,vs; tl.getEffects())
        {
            foreach (v; vs)
            final switch (v.type)
            {
                case TextureUnitState.TextureEffectType.ET_ENVIRONMENT_MAP:
                    if (v.subtype == TextureUnitState.EnvMapType.ENV_CURVED)
                    {
                        _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP);
                        anyCalcs = true;
                    }
                    else if (v.subtype == TextureUnitState.EnvMapType.ENV_PLANAR)
                    {
                        _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_PLANAR);
                        anyCalcs = true;
                    }
                    else if (v.subtype == TextureUnitState.EnvMapType.ENV_REFLECTION)
                    {
                        _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_REFLECTION);
                        anyCalcs = true;
                    }
                    else if (v.subtype == TextureUnitState.EnvMapType.ENV_NORMAL)
                    {
                        _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_ENVIRONMENT_MAP_NORMAL);
                        anyCalcs = true;
                    }
                    break;
                case TextureUnitState.TextureEffectType.ET_UVSCROLL:
                case TextureUnitState.TextureEffectType.ET_USCROLL:
                case TextureUnitState.TextureEffectType.ET_VSCROLL:
                case TextureUnitState.TextureEffectType.ET_ROTATE:
                case TextureUnitState.TextureEffectType.ET_TRANSFORM:
                    break;
                case TextureUnitState.TextureEffectType.ET_PROJECTIVE_TEXTURE:
                    _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_PROJECTIVE_TEXTURE,
                                                v.frustum);
                    anyCalcs = true;
                    break;
            }
        }
        // Ensure any previous texcoord calc settings are reset if there are now none
        if (!anyCalcs)
        {
            _setTextureCoordCalculation(texUnit, TexCoordCalcMethod.TEXCALC_NONE);
        }

        // Change tetxure matrix
        _setTextureMatrix(texUnit, tl.getTextureTransform());

    }

    /** Turns off a texture unit. */
    void _disableTextureUnit(size_t texUnit)
    {
        _setTexture(texUnit, false, sNullTexPtr);
    }

    /** Disables all texture units from the given unit upwards */
    void _disableTextureUnitsFrom(size_t texUnit)
    {
        size_t disableTo = OGRE_MAX_TEXTURE_LAYERS;
        if (disableTo > mDisabledTexUnitsFrom)
            disableTo = mDisabledTexUnitsFrom;
        mDisabledTexUnitsFrom = texUnit;
        foreach (size_t i; texUnit..disableTo)
        {
            _disableTextureUnit(i);
        }
    }
    /** Sets the surface properties to be used for future rendering.

     This method sets the the properties of the surfaces of objects
     to be rendered after it. In this context these surface properties
     are the amount of each type of light the object reflects (determining
     it's colour under different types of light), whether it emits light
     itself, and how shiny it is. Textures are not dealt with here,
     see the _setTetxure method for details.
     This method is used by _setMaterial so does not need to be called
     direct if that method is being used.

     @param ambient The amount of ambient (sourceless and directionless)
     light an object reflects. Affected by the colour/amount of ambient light in the scene.
     @param diffuse The amount of light from directed sources that is
     reflected (affected by colour/amount of point, directed and spot light sources)
     @param specular The amount of specular light reflected. This is also
     affected by directed light sources but represents the colour at the
     highlights of the object.
     @param emissive The colour of light emitted from the object. Note that
     this will make an object seem brighter and not dependent on lights in
     the scene, but it will not act as a light, so will not illuminate other
     objects. Use a light attached to the same SceneNode as the object for this purpose.
     @param shininess A value which only has an effect on specular highlights (so
     specular must be non-black). The higher this value, the smaller and crisper the
     specular highlights will be, imitating a more highly polished surface.
     This value is notrained to 0.0-1.0, in fact it is likely to
     be more (10.0 gives a modest sheen to an object).
     @param tracking A bit field that describes which of the ambient, diffuse, specular
     and emissive colours follow the vertex colour of the primitive. When a bit in this field is set
     its ColourValue is ignored. This is a combination of TVC_AMBIENT, TVC_DIFFUSE, TVC_SPECULAR(note that the shininess value is still
     taken from shininess) and TVC_EMISSIVE. TVC_NONE means that there will be no material property
     tracking the vertex colours.
     */
     //TODO If some perf optimization advantage then wrap ColourValues in const
    abstract void _setSurfaceParams(ColourValue ambient,
                                    ColourValue diffuse, ColourValue specular,
                                    ColourValue emissive, Real shininess,
                                    TrackVertexColour tracking = /*TVC_NONE*/ 0); //TODO uh wtf cant find TVC_NONE?

    /** Sets whether or not rendering points using OT_POINT_LIST will
     render point sprites (textured quads) or plain points.
     @param enabled True enables point sprites, false returns to normal
     point rendering.
     */
    abstract void _setPointSpritesEnabled(bool enabled);

    /** Sets the size of points and how they are attenuated with distance.
     @remarks
     When performing point rendering or point sprite rendering,
     point size can be attenuated with distance. The equation for
     doing this is attenuation = 1 / (constant + linear * dist + quadratic * d^2) .
     @par
     For example, to disable distance attenuation (constant screensize)
     you would setant to 1, and linear and quadratic to 0. A
     standard perspective attenuation would be 0, 1, 0 respectively.
     */
    abstract void _setPointParameters(Real size, bool attenuationEnabled,
                                      Real constant, Real linear, Real quadratic, Real minSize, Real maxSize);

    
    /**
     Sets the texture to bind to a given texture unit.

     User processes would not normally call this direct unless rendering
     primitives themselves.

     @param unit The index of the texture unit to modify. Multitexturing
     hardware can support multiple units (see
     RenderSystemCapabilites::getNumTextureUnits)
     @param enabled Boolean to turn the unit on/off
     @param texPtr Pointer to the texture to use.
     */
    abstract void _setTexture(size_t unit, bool enabled,
                              const(SharedPtr!Texture) texPtr);
    /**
     Sets the texture to bind to a given texture unit.

     User processes would not normally call this direct unless rendering
     primitives themselves.

     @param unit The index of the texture unit to modify. Multitexturing
     hardware can support multiple units (see
     RenderSystemCapabilites::getNumTextureUnits)
     @param enabled Boolean to turn the unit on/off
     @param texname The name of the texture to use - this should have
     already been loaded with TextureManager::load.
     */
    void _setTexture(size_t unit, bool enabled,string texname)
    {
        SharedPtr!Texture t = TextureManager.getSingleton().getByName(texname);
        _setTexture(unit, enabled, t);
    }

    /** Binds a texture to a vertex sampler.
     @remarks
     Not all rendersystems support separate vertex samplers. For those that
     do, you can set a texture for them, separate to the regular texture
     samplers, using this method. For those that don't, you should use the
     regular texture samplers which are shared between the vertex and
     fragment units; calling this method will throw an exception.
     @see RenderSystemCapabilites::getVertexTextureUnitsShared
     */
    void _setVertexTexture(size_t unit, SharedPtr!Texture tex)
    {
        throw new NotImplementedError(
            "This rendersystem does not support separate vertex texture samplers, " ~
            "you should use the regular texture samplers which are shared between " ~
            "the vertex and fragment units.",
            "RenderSystem._setVertexTexture");
    }

    /**
     Sets the texture coordinate set to use for a texture unit.

     Meant for use internally - not generally used directly by apps - the Material and TextureUnitState
     classes let you manage textures far more easily.

     @param unit Texture unit as above
     @param index The index of the texture coordinate set to use.
     */
    abstract void _setTextureCoordSet(size_t unit, size_t index);

    /**
     Sets a method for automatically calculating texture coordinates for a stage.
     Should not be used by apps - for use by Ogre only.
     @param unit Texture unit as above
     @param m Calculation method to use
     @param frustum Optional Frustum param, only used for projective effects
     */
    abstract void _setTextureCoordCalculation(size_t unit, TexCoordCalcMethod m,
                                              const(Frustum) frustum = null);

    /** Sets the texture blend modes from a TextureUnitState record.
     Meant for use internally only - apps should use the Material
     and TextureUnitState classes.
     @param unit Texture unit as above
     @param bm Details of the blending mode
     */
    abstract void _setTextureBlendMode(size_t unit, const(LayerBlendModeEx) bm);

    /** Sets the filtering options for a given texture unit.
     @param unit The texture unit to set the filtering options for
     @param minFilter The filter used when a texture is reduced in size
     @param magFilter The filter used when a texture is magnified
     @param mipFilter The filter used between mipmap levels, FO_NONE disables mipmapping
     */
    void _setTextureUnitFiltering(size_t unit, FilterOptions minFilter,
                                  FilterOptions magFilter, FilterOptions mipFilter)
    {
        _setTextureUnitFiltering(unit, FilterType.FT_MIN, minFilter);
        _setTextureUnitFiltering(unit, FilterType.FT_MAG, magFilter);
        _setTextureUnitFiltering(unit, FilterType.FT_MIP, mipFilter);
    }

    /** Sets a single filter for a given texture unit.
     @param unit The texture unit to set the filtering options for
     @param ftype The filter type
     @param filter The filter to be used
     */
    abstract void _setTextureUnitFiltering(size_t unit, FilterType ftype, FilterOptions filter);

    /** Sets wether the compare func is enabled or not for this texture unit
     @param unit The texture unit to set the filtering options for
     @param compare The state (enabled/disabled)
     */
    abstract void _setTextureUnitCompareEnabled(size_t unit, bool compare);

    
    /** Sets the compare function to use for a given texture unit
     @param unit The texture unit to set the filtering options for
     @param function The comparison function
     */
    abstract void _setTextureUnitCompareFunction(size_t unit, CompareFunction func);

    
    /** Sets the maximal anisotropy for the specified texture unit.*/
    abstract void _setTextureLayerAnisotropy(size_t unit, uint maxAnisotropy);

    /** Sets the texture addressing mode for a texture unit.*/
    abstract void _setTextureAddressingMode(size_t unit, const(TextureUnitState.UVWAddressingMode) uvw);

    /** Sets the texture border colour for a texture unit.*/
    abstract void _setTextureBorderColour(size_t unit, const(ColourValue) colour);

    /** Sets the mipmap bias value for a given texture unit.
     @remarks
     This allows you to adjust the mipmap calculation up or down for a
     given texture unit. Negative values force a larger mipmap to be used,
     positive values force a smaller mipmap to be used. Units are in numbers
     of levels, so +1 forces the mipmaps to one smaller level.
     @note Only does something if render system has capability RSC_MIPMAP_LOD_BIAS.
     */
    abstract void _setTextureMipmapBias(size_t unit, float bias);

    /** Sets the texture coordinate transformation matrix for a texture unit.
     @param unit Texture unit to affect
     @param xform The 4x4 matrix
     */
    abstract void _setTextureMatrix(size_t unit, const(Matrix4) xform);

    /** Sets the global blending factors for combining subsequent renders with the existing frame contents.
     The result of the blending operation is:</p>
     <p align="center">final = (texture * sourceFactor) + (pixel * destFactor)</p>
     Each of the factors is specified as one of a number of options, as specified in the SceneBlendFactor
     enumerated type.
     By changing the operation you can change addition between the source and destination pixels to a different operator.
     @param sourceFactor The source factor in the above calculation, i.e. multiplied by the texture colour components.
     @param destFactor The destination factor in the above calculation, i.e. multiplied by the pixel colour components.
     @param op The blend operation mode for combining pixels
     */
    abstract void _setSceneBlending(SceneBlendFactor sourceFactor, SceneBlendFactor destFactor, SceneBlendOperation op = SceneBlendOperation.SBO_ADD);

    /** Sets the global blending factors for combining subsequent renders with the existing frame contents.
     The result of the blending operation is:</p>
     <p align="center">final = (texture * sourceFactor) + (pixel * destFactor)</p>
     Each of the factors is specified as one of a number of options, as specified in the SceneBlendFactor
     enumerated type.
     @param sourceFactor The source factor in the above calculation, i.e. multiplied by the texture colour components.
     @param destFactor The destination factor in the above calculation, i.e. multiplied by the pixel colour components.
     @param sourceFactorAlpha The source factor in the above calculation for the alpha channel, i.e. multiplied by the texture alpha components.
     @param destFactorAlpha The destination factor in the above calculation for the alpha channel, i.e. multiplied by the pixel alpha components.
     @param op The blend operation mode for combining pixels
     @param alphaOp The blend operation mode for combining pixel alpha values
     */
    abstract void _setSeparateSceneBlending(SceneBlendFactor sourceFactor, SceneBlendFactor destFactor, SceneBlendFactor sourceFactorAlpha,
                                            SceneBlendFactor destFactorAlpha, SceneBlendOperation op = SceneBlendOperation.SBO_ADD,
                                            SceneBlendOperation alphaOp = SceneBlendOperation.SBO_ADD);

    /** Sets the global alpha rejection approach for future renders.
     By default images are rendered regardless of texture alpha. This method lets you change that.
     @param func The comparison function which must pass for a pixel to be written.
     @param value The value to compare each pixels alpha value to (0-255)
     @param alphaToCoverage Whether to enable alpha to coverage, if supported
     */
    abstract void _setAlphaRejectSettings(CompareFunction func, ubyte value, bool alphaToCoverage);

    /** Notify the rendersystem that it should adjust texture projection to be
     relative to a different origin.
     */
    void _setTextureProjectionRelativeTo(bool enabled,Vector3 pos)
    {
        mTexProjRelative = enabled;
        mTexProjRelativeOrigin = pos;
    }

    /** Creates a DepthBuffer that can be attached to the specified RenderTarget
     @remarks
     It doesn't attach anything, it just returns a pointer to a new DepthBuffer
     Caller is responsible for putting this buffer into the right pool, for
     attaching, and deleting it. Here's where API-specific magic happens.
     Don't call this directly unless you know what you're doing.
     */
    abstract DepthBuffer _createDepthBufferFor( RenderTarget renderTarget );

    /** Removes all depth buffers. Should be called on device lost and shutdown
     @remarks
     Advanced users can call this directly with bCleanManualBuffers=false to
     remove all depth buffers created for RTTs; when they think the pool has
     grown too big or they've used lots of depth buffers they don't need anymore,
     freeing GPU RAM.
     */
    void _cleanupDepthBuffers( bool bCleanManualBuffers=true )
    {
        foreach(k,pool; mDepthBufferPool)
        {

            foreach(v; pool)
            {
                if( bCleanManualBuffers || !v.isManual() )
                    destroy(v);
            }

            pool.clear();
        }

        mDepthBufferPool.clear();
    }

    /**
     * Signifies the beginning of a frame, i.e. the start of rendering on a single viewport. Will occur
     * several times per complete frame if multiple viewports exist.
     */
    abstract void _beginFrame();

    //Dummy structure for render system contexts - implementing RenderSystems can extend
    //as needed
    //struct
    class RenderSystemContext { };
    /**
     * Pause rendering for a frame. This has to be called after _beginFrame and before _endFrame.
     * Will usually be called by the SceneManager, don't use this manually unless you know what
     * you are doing.
     */
    RenderSystemContext _pauseFrame()
    {
        _endFrame();
        return new RenderSystem.RenderSystemContext;
    }
    /**
     * Resume rendering for a frame. This has to be called after a _pauseFrame call
     * Will usually be called by the SceneManager, don't use this manually unless you know what
     * you are doing.
     * @param context the render system context, as returned by _pauseFrame
     */
    void _resumeFrame(ref RenderSystemContext context)
    {
        _beginFrame();
        destroy(context);
    }

    /**
     * Ends rendering of a frame to the current viewport.
     */
    abstract void _endFrame();
    /**
     Sets the provided viewport as the active one for future
     rendering operations. This viewport is aware of it's own
     camera and render target. Must be implemented by subclass.

     @param vp Pointer to the appropriate viewport.
     */
    abstract void _setViewport(Viewport vp);
    /** Get the current active viewport for rendering. */
    ref Viewport _getViewport()
    {
        return mActiveViewport;
    }

    /** Sets the culling mode for the render system based on the 'vertex winding'.
     A typical way for the rendering engine to cull triangles is based on the
     'vertex winding' of triangles. Vertex winding ref ers to the direction in
     which the vertices are passed or indexed to in the rendering operation as viewed
     from the camera, and will wither be clockwise or anticlockwise (that's 'counterclockwise' for
     you Americans out there ;) The default is CULL_CLOCKWISE i.e. that only triangles whose vertices
     are passed/indexed in anticlockwise order are rendered - this is a common approach and is used in 3D studio models
     for example. You can alter this culling mode if you wish but it is not advised unless you know what you are doing.
     You may wish to use the CULL_NONE option for mesh data that you cull yourself where the vertex
     winding is uncertain.
     */
    abstract void _setCullingMode(CullingMode mode);

    CullingMode _getCullingMode()
    {
        return mCullingMode;
    }

    /** Sets the mode of operation for depth buffer tests from this point onwards.
     Sometimes you may wish to alter the behaviour of the depth buffer to achieve
     special effects. Because it's unlikely that you'll set these options for an entire frame,
     but rather use them to tweak settings between rendering objects, this is an internal
     method (indicated by the '_' prefix) which will be used by a SceneManager implementation
     rather than directly from the client application.
     If this method is never called the settings are automatically the same as the default parameters.
     @param depthTest If true, the depth buffer is tested for each pixel and the frame buffer is only updated
     if the depth function test succeeds. If false, no test is performed and pixels are always written.
     @param depthWrite If true, the depth buffer is updated with the depth of the new pixel if the depth test succeeds.
     If false, the depth buffer is left unchanged even if a new pixel is written.
     @param depthFunction Sets the function required for the depth test.
     */
    abstract void _setDepthBufferParams(bool depthTest = true, bool depthWrite = true, CompareFunction depthFunction = CompareFunction.CMPF_LESS_EQUAL);

    /** Sets whether or not the depth buffer check is performed before a pixel write.
     @param enabled If true, the depth buffer is tested for each pixel and the frame buffer is only updated
     if the depth function test succeeds. If false, no test is performed and pixels are always written.
     */
    abstract void _setDepthBufferCheckEnabled(bool enabled = true);
    /** Sets whether or not the depth buffer is updated after a pixel write.
     @param enabled If true, the depth buffer is updated with the depth of the new pixel if the depth test succeeds.
     If false, the depth buffer is left unchanged even if a new pixel is written.
     */
    abstract void _setDepthBufferWriteEnabled(bool enabled = true);
    /** Sets the comparison function for the depth buffer check.
     Advanced use only - allows you to choose the function applied to compare the depth values of
     new and existing pixels in the depth buffer. Only an issue if the deoth buffer check is enabled
     (see _setDepthBufferCheckEnabled)
     @param  func The comparison between the new depth and the existing depth which must return true
     for the new pixel to be written.
     */
    abstract void _setDepthBufferFunction(CompareFunction func = CompareFunction.CMPF_LESS_EQUAL);
    /** Sets whether or not colour buffer writing is enabled, and for which channels.
     @remarks
     For some advanced effects, you may wish to turn off the writing of certain colour
     channels, or even all of the colour channels so that only the depth buffer is updated
     in a rendering pass. However, the chances are that you really want to use this option
     through the Material class.
     @param red, green, blue, alpha Whether writing is enabled for each of the 4 colour channels. */
    abstract void _setColourBufferWriteEnabled(bool red, bool green, bool blue, bool alpha);
    /** Sets the depth bias, NB you should use the Material version of this.
     @remarks
     When polygons are coplanar, you can get problems with 'depth fighting' where
     the pixels from the two polys compete for the same screen pixel. This is particularly
     a problem for decals (polys attached to another surface to represent details such as
     bulletholes etc.).
     @par
     A way to combat this problem is to use a depth bias to adjust the depth buffer value
     used for the decal such that it is slightly higher than the true value, ensuring that
     the decal appears on top.
     @note
     The final bias value is a combination of aant bias and a bias proportional
     to the maximum depth slope of the polygon being rendered. The final bias
     is constantBias + slopeScaleBias * maxslope. Slope scale biasing is
     generally preferable but is not available on older hardware.
     @param constantBias The constant bias value, expressed as a value in
     homogeneous depth coordinates.
     @param slopeScaleBias The bias value which is factored by the maximum slope
     of the polygon, see the description above. This is not supported by all
     cards.

     */
    abstract void _setDepthBias(float constantBias, float slopeScaleBias = 0.0f);
    /** Sets the fogging mode for future geometry.
     @param mode Set up the mode of fog as described in the FogMode enum, or set to FOG_NONE to turn off.
     @param colour The colour of the fog. Either set this to the same as your viewport background colour,
     or to blend in with a skydome or skybox.
     @param expDensity The density of the fog in FOG_EXP or FOG_EXP2 mode, as a value between 0 and 1. The default is 1. i.e. completely opaque, lower values can mean
     that fog never completely obscures the scene.
     @param linearStart Distance at which linear fog starts to encroach. The distance must be passed
     as a parametric value between 0 and 1, with 0 being the near clipping plane, and 1 being the far clipping plane. Only applicable if mode is FOG_LINEAR.
     @param linearEnd Distance at which linear fog becomes completely opaque.The distance must be passed
     as a parametric value between 0 and 1, with 0 being the near clipping plane, and 1 being the far clipping plane. Only applicable if mode is FOG_LINEAR.
     */
    abstract void _setFog(FogMode mode = FogMode.FOG_NONE,ColourValue colour = ColourValue.White, Real expDensity = 1.0, Real linearStart = 0.0, Real linearEnd = 1.0);

    
    /** The RenderSystem will keep a count of tris rendered, this resets the count. */
    void _beginGeometryCount()
    {
        mBatchCount = mFaceCount = mVertexCount = 0;
    }
    /** Reports the number of tris rendered since the last _beginGeometryCount call. */
    uint _getFaceCount()
    {
        return cast(uint)( mFaceCount );
    }
    /** Reports the number of batches rendered since the last _beginGeometryCount call. */
    uint _getBatchCount()
    {
        return cast(uint)( mBatchCount );
    }
    /** Reports the number of vertices passed to the renderer since the last _beginGeometryCount call. */
    uint _getVertexCount()
    {
        return cast(uint)( mVertexCount );
    }

    /** Generates a packed data version of the passed in ColourValue suitable for
     use as with this RenderSystem.
     @remarks
     Since different render systems have different colour data formats (eg
     RGBA for GL, ARGB for D3D) this method allows you to use 1 method for all.
     @param colour The colour to convert
     @param pDest Pointer to location to put the result.
     */
    void convertColourValue(ColourValue colour, uint* pDest)
    {
        *pDest = VertexElement.convertColourValue(colour, getColourVertexElementType());
    }
    /** Get the native VertexElementType for a compact 32-bit colour value
     for this rendersystem.
     */
    abstract VertexElementType getColourVertexElementType();

    /** Converts a uniform projection matrix to suitable for this render system.
     @remarks
     Because different APIs have different requirements (some incompatible) for the
     projection matrix, this method allows each to implement their own correctly and pass
     back a generic OGRE matrix for storage in the engine.
     */
    abstract void _convertProjectionMatrix(const(Matrix4) matrix,
                                           ref Matrix4 dest, bool forGpuProgram = false);

    /** Builds a perspective projection matrix suitable for this render system.
     @remarks
     Because different APIs have different requirements (some incompatible) for the
     projection matrix, this method allows each to implement their own correctly and pass
     back a generic OGRE matrix for storage in the engine.
     */
    abstract void _makeProjectionMatrix(const(Radian) fovy, Real aspect, Real nearPlane, Real farPlane,
                                        ref Matrix4 dest, bool forGpuProgram = false);

    /** Builds a perspective projection matrix for the case when frustum is
     not centered around camera.
     @remarks
     Viewport coordinates are in camera coordinate frame, i.e. camera is
     at the origin.
     */
    abstract void _makeProjectionMatrix(Real left, Real right, Real bottom, Real top,
                                        Real nearPlane, Real farPlane, ref Matrix4 dest, bool forGpuProgram = false);
    /** Builds an orthographic projection matrix suitable for this render system.
     @remarks
     Because different APIs have different requirements (some incompatible) for the
     projection matrix, this method allows each to implement their own correctly and pass
     back a generic OGRE matrix for storage in the engine.
     */
    abstract void _makeOrthoMatrix(const(Radian) fovy, Real aspect, Real nearPlane, Real farPlane,
                                   ref Matrix4 dest, bool forGpuProgram = false);

    /** Update a perspective projection matrix to use 'oblique depth projection'.
     @remarks
     This method can be used to change the nature of a perspective
     transform in order to make the near plane not perpendicular to the
     camera view direction, but to be at some different orientation.
     This can be useful for performing arbitrary clipping (e.g. to a
     reflection plane) which could otherwise only be done using user
     clip planes, which are more expensive, and not necessarily supported
     on all cards.
     @param matrix The existing projection matrix. Note that this must be a
     perspective transform (not orthographic), and must not have already
     been altered by this method. The matrix will be altered in-place.
     @param plane The plane which is to be used as the clipping plane. This
     plane must be in CAMERA (view) space.
     @param forGpuProgram Is this for use with a Gpu program or fixed-function
     */
    abstract void _applyObliqueDepthProjection(ref Matrix4 matrix, const(Plane) plane,
                                               bool forGpuProgram);

    /** Sets how to rasterise triangles, as points, wiref rame or solid polys. */
    abstract void _setPolygonMode(PolygonMode level);

    /** Turns stencil buffer checking on or off.
     @remarks
     Stencilling (masking off areas of the rendering target based on the stencil
     buffer) can be turned on or off using this method. By default, stencilling is
     disabled.
     */
    abstract void setStencilCheckEnabled(bool enabled);
    /** Determines if this system supports hardware accelerated stencil buffer.
     @remarks
     Note that the lack of this function doesn't mean you can't do stencilling, but
     the stencilling operations will be provided in software, which will NOT be
     fast.
     @par
     Generally hardware stencils are only supported in 32-bit colour modes, because
     the stencil buffer shares the memory of the z-buffer, and in most cards the
     z-buffer has to be the same depth as the colour buffer. This means that in 32-bit
     mode, 24 bits of the z-buffer are depth and 8 bits are stencil. In 16-bit mode there
     is no room for a stencil (although some cards support a 15:1 depth:stencil option,
     this isn't useful for very much) so 8 bits of stencil are provided in software.
     This can mean that if you use stencilling, your applications may be faster in
     32-but colour than in 16-bit, which may seem odd to some people.
     */
    /*bool hasHardwareStencil();*/

    /** This method allows you to set all the stencil buffer parameters in one call.
     @remarks
     The stencil buffer is used to mask out pixels in the render target, allowing
     you to do effects like mirrors, cut-outs, stencil shadows and more. Each of
     your batches of rendering is likely to ignore the stencil buffer,
     update it with new values, or apply it to mask the output of the render.
     The stencil test is:<PRE>
     (Reference Value & Mask) CompareFunction (Stencil Buffer Value & Mask)</PRE>
     The result of this will cause one of 3 actions depending on whether the test fails,
     succeeds but with the depth buffer check still failing, or succeeds with the
     depth buffer check passing too.
     @par
     Unlike other render states, stencilling is left for the application to turn
     on and off when it requires. This is because you are likely to want to change
     parameters between batches of arbitrary objects and control the ordering yourself.
     In order to batch things this way, you'll want to use OGRE's separate render queue
     groups (see RenderQueue) and register a RenderQueueListener to get notifications
     between batches.
     @par
     There are individual state change methods for each of the parameters set using
     this method.
     Note that the default values in this method represent the defaults at system
     start up too.
     @param func The comparison function applied.
     @param ref Value The reference value used in the comparison
     @param compareMask The bitmask applied to both the stencil value and the reference value
     before comparison
     @param writeMask The bitmask the controls which bits from ref Value will be written to
     stencil buffer (valid for operations such as SOP_REPLACE).
     the stencil
     @param stencilFailOp The action to perform when the stencil check fails
     @param depthFailOp The action to perform when the stencil check passes, but the
     depth buffer check still fails
     @param passOp The action to take when both the stencil and depth check pass.
     @param twoSidedOperation If set to true, then if you render both back and front faces
     (you'll have to turn off culling) then these parameters will apply for front faces,
     and the inverse of them will happen for back faces (keep remains the same).
     */
    abstract void setStencilBufferParams(CompareFunction func = CompareFunction.CMPF_ALWAYS_PASS,
                                         uint refValue = 0, uint compareMask = 0xFFFFFFFF, uint writeMask = 0xFFFFFFFF,
                                         StencilOperation stencilFailOp = StencilOperation.SOP_KEEP,
                                         StencilOperation depthFailOp = StencilOperation.SOP_KEEP,
                                         StencilOperation passOp = StencilOperation.SOP_KEEP,
                                         bool twoSidedOperation = false);

    

    /** Sets the current vertex declaration, ie the source of vertex data. */
    abstract void setVertexDeclaration(VertexDeclaration decl);
    /** Sets the current vertex buffer binding state. */
    abstract void setVertexBufferBinding(VertexBufferBinding binding);

    /** Sets whether or not normals are to be automatically normalised.
     @remarks
     This is useful when, for example, you are scaling SceneNodes such that
     normals may not be unit-length anymore. Note though that this has an
     overhead so should not be turn on unless you really need it.
     @par
     You should not normally call this direct unless you are rendering
     world geometry; set it on the Renderable because otherwise it will be
     overridden by material settings.
     */
    abstract void setNormaliseNormals(bool normalise);

    /**
     Render something to the active viewport.

     Low-level rendering interface to perform rendering
     operations. Unlikely to be used directly by client
     applications, since the SceneManager and various support
     classes will be responsible for calling this method.
     Can only be called between _beginScene and _endScene

     @param op A rendering operation instance, which contains
     details of the operation to be performed.
     */
    void _render(RenderOperation op)
    {
        // Update stats
        size_t val;

        if (op.useIndexes)
            val = op.indexData.indexCount;
        else
            val = op.vertexData.vertexCount;

        size_t trueInstanceNum = std.algorithm.max(op.numberOfInstances,1);
        val *= trueInstanceNum;

        // account for a pass having multiple iterations
        if (mCurrentPassIterationCount > 1)
            val *= mCurrentPassIterationCount;
        mCurrentPassIterationNum = 0;

        switch(op.operationType)
        {
            case RenderOperation.OperationType.OT_TRIANGLE_LIST:
                mFaceCount += (val / 3);
                break;
            case RenderOperation.OperationType.OT_TRIANGLE_STRIP:
            case RenderOperation.OperationType.OT_TRIANGLE_FAN:
                mFaceCount += (val - 2);
                break;
            case RenderOperation.OperationType.OT_POINT_LIST:
            case RenderOperation.OperationType.OT_LINE_LIST:
            case RenderOperation.OperationType.OT_LINE_STRIP:
            case RenderOperation.OperationType.OT_PATCH_1_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_2_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_3_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_4_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_5_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_6_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_7_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_8_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_9_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_10_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_11_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_12_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_13_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_14_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_15_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_16_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_17_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_18_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_19_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_20_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_21_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_22_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_23_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_24_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_25_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_26_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_27_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_28_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_29_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_30_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_31_CONTROL_POINT:
            case RenderOperation.OperationType.OT_PATCH_32_CONTROL_POINT:
                break;
            default:
                assert(false, "Unsupported render operation.");
        }

        mVertexCount += op.vertexData.vertexCount * trueInstanceNum;
        mBatchCount += mCurrentPassIterationCount;

        // sort out clip planes
        // have to do it here in case of matrix issues
        if (mClipPlanesDirty)
        {
            setClipPlanesImpl(mClipPlanes);
            mClipPlanesDirty = false;
        }
    }

    /** Gets the capabilities of the render system. */
    RenderSystemCapabilities getCapabilities(){ return mCurrentCapabilities; }

    
    /** Returns the driver version.
     */
    DriverVersion getDriverVersion(){ return mDriverVersion; }

    /** Returns the default material scheme used by the render system.
     Systems that use the RTSS to emulate a fixed function pipeline
     (e.g. OpenGL ES 2, DX11) need to override this function to return
     the default material scheme of the RTSS ShaderGenerator.

     This is currently only used to set the default material scheme for
     viewports.  It is a necessary step on these render systems for
     render textures to be rendered into properly.
     */
    string _getDefaultViewportMaterialScheme()
    {

        static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
        {
            if ( !(getCapabilities().hasCapability(RSC_FIXED_FUNCTION)) )
            {
                // I am returning the exact value for now - I don't want to add dependency for the RTSS just for one string
                static string ShaderGeneratorDefaultScheme = "ShaderGeneratorDefaultScheme";
                return ShaderGeneratorDefaultScheme;
            }
        }

        return MaterialManager.DEFAULT_SCHEME_NAME;
    }

    /** Binds a given GpuProgram (but not the parameters).
     @remarks Only one GpuProgram of each type can be bound at once, binding another
     one will simply replace the existing one.
     */
    void bindGpuProgram(GpuProgram prg)
    {
        switch(prg.getType())
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                // mark clip planes dirty if changed (programmable can change space)
                if (!mVertexProgramBound && !mClipPlanes.empty())
                    mClipPlanesDirty = true;

                mVertexProgramBound = true;
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                mGeometryProgramBound = true;
                break;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                mFragmentProgramBound = true;
                break;
            case GpuProgramType.GPT_HULL_PROGRAM:
                mTesselationHullProgramBound = true;
                break;
            case GpuProgramType.GPT_DOMAIN_PROGRAM:
                mTesselationDomainProgramBound = true;
                break;
            case GpuProgramType.GPT_COMPUTE_PROGRAM:
                mComputeProgramBound = true;
                break;
            default:
                assert(false, "Unsupported gpu program type.");
        }
    }

    /** Bind Gpu program parameters.
     @param gptype The type of program to bind the parameters to
     @param params The parameters to bind
     @param variabilityMask A mask of GpuParamVariability identifying which params need binding
     */
    abstract void bindGpuProgramParameters(GpuProgramType gptype,
                                           GpuProgramParametersPtr params, ushort variabilityMask);

    /** Only binds Gpu program parameters used for passes that have more than one iteration rendering
     */
    abstract void bindGpuProgramPassIterationParameters(GpuProgramType gptype);
    /** Unbinds GpuPrograms of a given GpuProgramType.
     @remarks
     This returns the pipeline to fixed-function processing for this type.
     */
    void unbindGpuProgram(GpuProgramType gptype)
    {
        switch(gptype)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                // mark clip planes dirty if changed (programmable can change space)
                if (mVertexProgramBound && !mClipPlanes.empty())
                    mClipPlanesDirty = true;
                mVertexProgramBound = false;
                break;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                mGeometryProgramBound = false;
                break;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                mFragmentProgramBound = false;
                break;
            case GpuProgramType.GPT_HULL_PROGRAM:
                mTesselationHullProgramBound = false;
                break;
            case GpuProgramType.GPT_DOMAIN_PROGRAM:
                mTesselationDomainProgramBound = false;
                break;
            case GpuProgramType.GPT_COMPUTE_PROGRAM:
                mComputeProgramBound = false;
                break;
            default:
                break;//TODO assert?
        }
    }

    /** Returns whether or not a Gpu program of the given type is currently bound. */
    bool isGpuProgramBound(GpuProgramType gptype)
    {
        switch(gptype)
        {
            case GpuProgramType.GPT_VERTEX_PROGRAM:
                return mVertexProgramBound;
            case GpuProgramType.GPT_GEOMETRY_PROGRAM:
                return mGeometryProgramBound;
            case GpuProgramType.GPT_FRAGMENT_PROGRAM:
                return mFragmentProgramBound;
            case GpuProgramType.GPT_HULL_PROGRAM:
                return mTesselationHullProgramBound;
            case GpuProgramType.GPT_DOMAIN_PROGRAM:
                return mTesselationDomainProgramBound;
            case GpuProgramType.GPT_COMPUTE_PROGRAM:
                return mComputeProgramBound;
            default:
                // Make compiler happy
                break;
        }
        // Make compiler happy
        return false;
    }

    /** Sets the user clipping region.
     */
    void setClipPlanes(PlaneList clipPlanes)
    {
        if (clipPlanes != mClipPlanes)//TODO proper comparison
        {
            mClipPlanes = clipPlanes;
            mClipPlanesDirty = true;
        }
    }

    /** Add a user clipping plane. */
    void addClipPlane (Plane p)
    {
        mClipPlanes.insert(p);
        mClipPlanesDirty = true;
    }

    /** Add a user clipping plane. */
    void addClipPlane (Real A, Real B, Real C, Real D)
    {
        addClipPlane(new Plane(A, B, C, D));
    }

    /** Clears the user clipping region.
     */
    void resetClipPlanes()
    {
        if (!mClipPlanes.empty())
        {
            mClipPlanes.clear();
            mClipPlanesDirty = true;
        }
    }

    /** Utility method for initialising all render targets attached to this rendering system. */
    void _initRenderTargets()
    {

        // Init stats
        foreach(k,v; mRenderTargets)
        {
            v.resetStatistics();
        }

    }

    /** Utility method to notify all render targets that a camera has been removed,
     in case they were ref erring to it as their viewer.
     */
    void _notifyCameraRemoved(Camera cam)
    {
        foreach (k,v; mRenderTargets)
        {
            v._notifyCameraRemoved(cam);
        }
    }

    /** Internal method for updating all render targets attached to this rendering system. */
    void _updateAllRenderTargets(bool swapBuffers = true)
    {
        // Update all in order of priority
        // This ensures render-to-texture targets get updated before render windows
        foreach(k,vs; mPrioritisedRenderTargets)
        {
            foreach(v;vs)
            if( v.isActive() && v.isAutoUpdated())
                v.update(swapBuffers);
        }
    }
    /** Internal method for swapping all the buffers on all render targets,
     if _updateAllRenderTargets was called with a 'false' parameter. */
    void _swapAllRenderTargetBuffers(bool waitForVsync = true)
    {
        // Update all in order of priority
        // This ensures render-to-texture targets get updated before render windows
        foreach( k,vs; mPrioritisedRenderTargets)
        {
            foreach( v; vs)
            if( v.isActive() && v.isAutoUpdated())
                v.swapBuffers(waitForVsync);
        }
    }

    /** Sets whether or not vertex windings set should be inverted; this can be important
     for rendering reflections. */
    void setInvertVertexWinding(bool invert)
    {
        mInvertVertexWinding = invert;
    }

    /** Indicates whether or not the vertex windings set will be inverted for the current render (e.g. reflections)
     @see RenderSystem::setInvertVertexWinding
     */
    bool getInvertVertexWinding()
    {
        return mInvertVertexWinding;
    }

    /** Sets the 'scissor region' ie the region of the target in which rendering can take place.
     @remarks
     This method allows you to 'mask off' rendering in all but a given rectangular area
     as identified by the parameters to this method.
     @note
     Not all systems support this method. Check the RenderSystemCapabilities for the
     RSC_SCISSOR_TEST capability to see if it is supported.
     @param enabled True to enable the scissor test, false to disable it.
     @param left, top, right, bottom The location of the corners of the rectangle, expressed in
     <i>pixels</i>.
     */
    abstract void setScissorTest(bool enabled, size_t left = 0, size_t top = 0,
                                 size_t right = 800, size_t bottom = 600);

    /** Clears one or more frame buffers on the active render target.
     @param buffers Combination of one or more elements of FrameBufferType
     denoting which buffers are to be cleared
     @param colour The colour to clear the colour buffer with, if enabled
     @param depth The value to initialise the depth buffer with, if enabled
     @param stencil The value to initialise the stencil buffer with, if enabled.
     */
    abstract void clearFrameBuffer(uint buffers,
                                   const(ColourValue) colour = ColourValue.Black,
                                   Real depth = 1.0f, ushort stencil = 0);
    /** Returns the horizontal texel offset value required for mapping
     texel origins to pixel origins in this rendersystem.
     @remarks
     Since rendersystems sometimes disagree on the origin of a texel,
     mapping from texels to pixels can sometimes be problematic to
     implement generically. This method allows you to retrieve the offset
     required to map the origin of a texel to the origin of a pixel in
     the horizontal direction.
     */
    abstract Real getHorizontalTexelOffset();
    /** Returns the vertical texel offset value required for mapping
     texel origins to pixel origins in this rendersystem.
     @remarks
     Since rendersystems sometimes disagree on the origin of a texel,
     mapping from texels to pixels can sometimes be problematic to
     implement generically. This method allows you to retrieve the offset
     required to map the origin of a texel to the origin of a pixel in
     the vertical direction.
     */
    abstract Real getVerticalTexelOffset();

    /** Gets the minimum (closest) depth value to be used when rendering
     using identity transforms.
     @remarks
     When using identity transforms you can manually set the depth
     of a vertex; however the input values required differ per
     rendersystem. This method lets you retrieve the correct value.
     @see Renderable::getUseIdentityView, Renderable::getUseIdentityProjection
     */
    abstract Real getMinimumDepthInputValue();
    /** Gets the maximum (farthest) depth value to be used when rendering
     using identity transforms.
     @remarks
     When using identity transforms you can manually set the depth
     of a vertex; however the input values required differ per
     rendersystem. This method lets you retrieve the correct value.
     @see Renderable::getUseIdentityView, Renderable::getUseIdentityProjection
     */
    abstract Real getMaximumDepthInputValue();
    /** set the current multi pass count value.  This must be set prior to
     calling _render() if multiple renderings of the same pass state are
     required.
     @param count Number of times to render the current state.
     */
    void setCurrentPassIterationCount(size_t count) { mCurrentPassIterationCount = count; }

    /** Tell the render system whether to derive a depth bias on its own based on
     the values passed to it in setCurrentPassIterationCount.
     The depth bias set will be baseValue + iteration * multiplier
     @param derive True to tell the RS to derive this automatically
     @param baseValue The base value to which the multiplier should be
     added
     @param multiplier The amount of depth bias to apply per iteration
     @param slopeScale The constant slope scale bias for completeness
     */
    void setDeriveDepthBias(bool derive, float baseValue = 0.0f,
                            float multiplier = 0.0f, float slopeScale = 0.0f)
    {
        mDerivedDepthBias = derive;
        mDerivedDepthBiasBase = baseValue;
        mDerivedDepthBiasMultiplier = multiplier;
        mDerivedDepthBiasSlopeScale = slopeScale;
    }

    /**
     * Set current render target to target, enabling its device context if needed
     */
    abstract void _setRenderTarget(RenderTarget target);

    /** Defines a listener on the custom events that this render system
     can raise.
     @see RenderSystem::addListener
     */
    interface Listener
    {
        /** A rendersystem-specific event occurred.
         @param eventName The name of the event which has occurred
         @param parameters A list of parameters that may belong to this event,
         may be null if there are no parameters
         */
        void eventOccurred(string eventName,
                           ref NameValuePairList parameters/* = null*/);
    }
    /** Adds a listener to the custom events that this render system can raise.
     @remarks
     Some render systems have quite specific, internally generated events
     that the application may wish to be notified of. Many applications
     don't have to worry about these events, and can just trust OGRE to
     handle them, but if you want to know, you can add a listener here.
     @par
     Events are raised very generically by string name. Perhaps the most
     common example of a render system specific event is the loss and
     restoration of a device in DirectX; which OGRE deals with, but you
     may wish to know when it happens.
     @see RenderSystem::getRenderSystemEvents
     */
    void addListener(ref Listener l)
    {
        mEventListeners.insert(l);
    }
    /** Remove a listener to the custom events that this render system can raise.
     */
    void removeListener(ref Listener l)
    {
        mEventListeners.removeFromArray(l);
    }

    /** Gets a list of the rendersystem specific events that this rendersystem
     can raise.
     @see RenderSystem::addListener
     */
    ref StringVector getRenderSystemEvents(){ return mEventNames; }

    /** Tell the rendersystem to perform any prep tasks it needs to directly
     before other threads which might access the rendering API are registered.
     @remarks
     Call this from your main thread before starting your other threads
     (which themselves should call registerThread()). Note that if you
     start your own threads, there is a specific startup sequence which
     must be respected and requires synchronisation between the threads:
     <ol>
     <li>[Main thread]Call preExtraThreadsStarted</li>
     <li>[Main thread]Start other thread, wait</li>
     <li>[Other thread]Call registerThread, notify main thread & continue</li>
     <li>[Main thread]Wake up & call postExtraThreadsStarted</li>
     </ol>
     Once this init sequence is completed the threads are independent but
     this startup sequence must be respected.
     */
    abstract void preExtraThreadsStarted();

    /* Tell the rendersystem to perform any tasks it needs to directly
     after other threads which might access the rendering API are registered.
     @see RenderSystem::preExtraThreadsStarted
     */
    abstract void postExtraThreadsStarted();

    /** Register the an additional thread which may make calls to rendersystem-related
     objects.
     @remarks
     This method should only be called by additional threads during their
     initialisation. If they intend to use hardware rendering system resources
     they should call this method before doing anything related to the render system.
     Some rendering APIs require a per-thread setup and this method will sort that
     out. It is also necessary to call unregisterThread before the thread shuts down.
     @note
     This method takes no parameters - it must be called from the thread being
     registered and that context is enough.
     */
    abstract void registerThread();

    /** Unregister an additional thread which may make calls to rendersystem-related objects.
     @see RenderSystem::registerThread
     */
    abstract void unregisterThread();

    /**
     * Gets the number of display monitors.
     @see Root::getDisplayMonitorCount
     */
    abstract uint getDisplayMonitorCount();

    /**
     * This marks the beginning of an event for GPU profiling.
     */
    abstract void beginProfileEvent(string eventName );

    /**
     * Ends the currently active GPU profiling event.
     */
    abstract void endProfileEvent();

    /**
     * Marks an instantaneous event for graphics profilers.
     * This is equivalent to calling @see beginProfileEvent and @see endProfileEvent back to back.
     */
    abstract void markProfileEvent(string event );

    /** Determines if the system has anisotropic mip map filter support
     */
    abstract bool hasAnisotropicMipMapFilter();

    /** Gets a custom (maybe platform-specific) attribute.
     @remarks This is a nasty way of satisfying any API's need to see platform-specific details. Applicable to D?
     @param name The name of the attribute.
     @param pData Pointer to memory of the right kind of structure to receive the info.
     */
    void getCustomAttribute(string name, void* pData)
    {
        throw new InvalidParamsError("Attribute not found.", "RenderSystem.getCustomAttribute");
    }

protected:

    /** DepthBuffers to be attached to render targets */
    DepthBufferMap  mDepthBufferPool;

    /** The render targets. */
    RenderTargetMap mRenderTargets;
    /** The render targets, ordered by priority. */
    RenderTargetPriorityMap mPrioritisedRenderTargets;
    /** The Active render target. */
    RenderTarget mActiveRenderTarget;

    /** The Active GPU programs and gpu program parameters*/
    GpuProgramParametersPtr mActiveVertexGpuProgramParameters;
    GpuProgramParametersPtr mActiveGeometryGpuProgramParameters;
    GpuProgramParametersPtr mActiveFragmentGpuProgramParameters;
    GpuProgramParametersPtr mActiveTesselationHullGpuProgramParameters;
    GpuProgramParametersPtr mActiveTesselationDomainGpuProgramParameters;
    GpuProgramParametersPtr mActiveComputeGpuProgramParameters;

    // Texture manager
    // A concrete class of this will be created and
    // made available under the TextureManager singleton,
    // managed by the RenderSystem
    TextureManager mTextureManager;

    // Active viewport (dest for future rendering operations)
    Viewport mActiveViewport;

    CullingMode mCullingMode;

    bool mVSync;
    uint mVSyncInterval;
    bool mWBuffer;

    size_t mBatchCount;
    size_t mFaceCount;
    size_t mVertexCount;

    /// Saved manual colour blends
    ColourValue[OGRE_MAX_TEXTURE_LAYERS][2] mManualBlendColours;

    bool mInvertVertexWinding;

    /// Texture units from this upwards are disabled
    size_t mDisabledTexUnitsFrom;

    /// number of times to render the current state
    size_t mCurrentPassIterationCount;
    size_t mCurrentPassIterationNum;
    /// Whether to update the depth bias per render call
    bool mDerivedDepthBias;
    float mDerivedDepthBiasBase;
    float mDerivedDepthBiasMultiplier;
    float mDerivedDepthBiasSlopeScale;

    /// a global vertex buffer for global instancing
    SharedPtr!HardwareVertexBuffer mGlobalInstanceVertexBuffer;
    /// a vertex declaration for the global vertex buffer for the global instancing
    VertexDeclaration mGlobalInstanceVertexBufferVertexDeclaration;
    /// the number of global instances (this number will be multiply by the render op instance number)
    size_t mGlobalNumberOfInstances;

    static if(RTSHADER_SYSTEM_BUILD_CORE_SHADERS)
    {
        /// is fixed pipeline enabled
        bool mEnableFixedPipeline;
    }

    /** updates pass iteration rendering state including bound gpu program parameter
     pass iteration auto constant entry
     @return True if more iterations are required
     */
    bool updatePassIterationRenderState()
    {
        if (mCurrentPassIterationCount <= 1)
            return false;

        --mCurrentPassIterationCount;
        ++mCurrentPassIterationNum;
        if (!mActiveVertexGpuProgramParameters.isNull())
        {
            mActiveVertexGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_VERTEX_PROGRAM);
        }
        if (!mActiveGeometryGpuProgramParameters.isNull())
        {
            mActiveGeometryGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_GEOMETRY_PROGRAM);
        }
        if (!mActiveFragmentGpuProgramParameters.isNull())
        {
            mActiveFragmentGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_FRAGMENT_PROGRAM);
        }
        if (!mActiveTesselationHullGpuProgramParameters.isNull())
        {
            mActiveTesselationHullGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_HULL_PROGRAM);
        }
        if (!mActiveTesselationDomainGpuProgramParameters.isNull())
        {
            mActiveTesselationDomainGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_DOMAIN_PROGRAM);
        }
        if (!mActiveComputeGpuProgramParameters.isNull())
        {
            mActiveComputeGpuProgramParameters.get().incPassIterationNumber();
            bindGpuProgramPassIterationParameters(GpuProgramType.GPT_COMPUTE_PROGRAM);
        }
        return true;
    }

    /// List of names of events this rendersystem may raise
    StringVector mEventNames;

    /// Internal method for firing a rendersystem event
    void fireEvent(string name,NameValuePairList params = NameValuePairList.init)
    {
        foreach(l; mEventListeners)
        {
            l.eventOccurred(name, params);
        }
    }

    //typedef list<Listener*>::type ListenerList;
    alias Listener[] ListenerList;
    ListenerList mEventListeners;

    //typedef list<HardwareOcclusionQuery*>::type HardwareOcclusionQueryList;
    alias HardwareOcclusionQuery[] HardwareOcclusionQueryList;
    HardwareOcclusionQueryList mHwOcclusionQueries;

    bool mVertexProgramBound;
    bool mGeometryProgramBound;
    bool mFragmentProgramBound;
    bool mTesselationHullProgramBound;
    bool mTesselationDomainProgramBound;
    bool mComputeProgramBound;

    // Recording user clip planes
    PlaneList mClipPlanes;
    // Indicator that we need to re-set the clip planes on next render call
    bool mClipPlanesDirty;

    /// Used to store the capabilities of the graphics card
    RenderSystemCapabilities mRealCapabilities;
    RenderSystemCapabilities mCurrentCapabilities;
    bool mUseCustomCapabilities;

    /// Internal method used to set the underlying clip planes when needed
    abstract void setClipPlanesImpl(const(PlaneList) clipPlanes);

    /** Initialize the render system from the capabilities*/
    abstract void initialiseFromRenderSystemCapabilities(RenderSystemCapabilities caps, RenderTarget primary);

    
    DriverVersion mDriverVersion;

    bool mTexProjRelative;
    Vector3 mTexProjRelativeOrigin;

}

enum uint CAPS_CATEGORY_SIZE = 4;
enum uint OGRE_CAPS_BITSHIFT = (32 - CAPS_CATEGORY_SIZE);
enum uint CAPS_CATEGORY_MASK = (((1 << CAPS_CATEGORY_SIZE) - 1) << OGRE_CAPS_BITSHIFT);

static uint OGRE_CAPS_VALUE(uint cat, uint val)
{
    return  ((cat << OGRE_CAPS_BITSHIFT) | (1 << val));
}

/// Enumerates the categories of capabilities
enum CapabilitiesCategory
{
    CAPS_CATEGORY_COMMON = 0,
    CAPS_CATEGORY_COMMON_2 = 1,
    CAPS_CATEGORY_D3D9 = 2,
    CAPS_CATEGORY_GL = 3,
    /// Placeholder for max value
    CAPS_CATEGORY_COUNT = 4
}

/// Enum describing the different hardware capabilities we want to check for
/// OGRE_CAPS_VALUE(a, b) defines each capability
// a is the category (which can be from 0 to 15)
// b is the value (from 0 to 27)
enum Capabilities
{
    /// Supports generating mipmaps in hardware
    RSC_AUTOMIPMAP              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 0),
    RSC_BLENDING                = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 1),
    /// Supports anisotropic texture filtering
    RSC_ANISOTROPY              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 2),
    /// Supports fixed-function DOT3 texture blend
    RSC_DOT3                    = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 3),
    /// Supports cube mapping
    RSC_CUBEMAPPING             = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 4),
    /// Supports hardware stencil buffer
    RSC_HWSTENCIL               = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 5),
    /// Supports hardware vertex and index buffers
    RSC_VBO                     = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 7),
    /// Supports vertex programs (vertex shaders)
    RSC_VERTEX_PROGRAM          = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 9),
    /// Supports fragment programs (pixel shaders)
    RSC_FRAGMENT_PROGRAM        = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 10),
    /// Supports performing a scissor test to exclude areas of the screen
    RSC_SCISSOR_TEST            = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 11),
    /// Supports separate stencil updates for both front and back faces
    RSC_TWO_SIDED_STENCIL       = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 12),
    /// Supports wrapping the stencil value at the range extremeties
    RSC_STENCIL_WRAP            = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 13),
    /// Supports hardware occlusion queries
    RSC_HWOCCLUSION             = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 14),
    /// Supports user clipping planes
    RSC_USER_CLIP_PLANES        = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 15),
    /// Supports the VET_UBYTE4 vertex element type
    RSC_VERTEX_FORMAT_UBYTE4    = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 16),
    /// Supports infinite far plane projection
    RSC_INFINITE_FAR_PLANE      = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 17),
    /// Supports hardware render-to-texture (bigger than framebuffer)
    RSC_HWRENDER_TO_TEXTURE     = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 18),
    /// Supports float textures and render targets
    RSC_TEXTURE_FLOAT           = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 19),
    /// Supports non-power of two textures
    RSC_NON_POWER_OF_2_TEXTURES = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 20),
    /// Supports 3d (volume) textures
    RSC_TEXTURE_3D              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 21),
    /// Supports basic point sprite rendering
    RSC_POINT_SPRITES           = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 22),
    /// Supports extra point parameters (minsize, maxsize, attenuation)
    RSC_POINT_EXTENDED_PARAMETERS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 23),
    /// Supports vertex texture fetch
    RSC_VERTEX_TEXTURE_FETCH = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 24),
    /// Supports mipmap LOD biasing
    RSC_MIPMAP_LOD_BIAS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 25),
    /// Supports hardware geometry programs
    RSC_GEOMETRY_PROGRAM = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 26),
    /// Supports rendering to vertex buffers
    RSC_HWRENDER_TO_VERTEX_BUFFER = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON, 27),
    
    /// Supports compressed textures
    RSC_TEXTURE_COMPRESSION = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 0),
    /// Supports compressed textures in the DXT/ST3C formats
    RSC_TEXTURE_COMPRESSION_DXT = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 1),
    /// Supports compressed textures in the VTC format
    RSC_TEXTURE_COMPRESSION_VTC = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 2),
    /// Supports compressed textures in the PVRTC format
    RSC_TEXTURE_COMPRESSION_PVRTC = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 3),
    /// Supports compressed textures in BC4 and BC5 format (DirectX feature level 10_0)
    RSC_TEXTURE_COMPRESSION_BC4_BC5 = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 4),
    /// Supports compressed textures in BC6H and BC7 format (DirectX feature level 11_0)
    RSC_TEXTURE_COMPRESSION_BC6H_BC7 = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 5),
    /// Supports fixed-function pipeline
    RSC_FIXED_FUNCTION = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 6),
    /// Supports MRTs with different bit depths
    RSC_MRT_DIFFERENT_BIT_DEPTHS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 7),
    /// Supports Alpha to Coverage (A2C)
    RSC_ALPHA_TO_COVERAGE = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 8),
    /// Supports Blending operations other than +
    RSC_ADVANCED_BLEND_OPERATIONS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 9),
    /// Supports a separate depth buffer for RTTs. D3D 9 & 10, OGL w/FBO (RSC_FBO implies this flag)
    RSC_RTT_SEPARATE_DEPTHBUFFER = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 10),
    /// Supports using the MAIN depth buffer for RTTs. D3D 9&10, OGL w/FBO support unknown
    /// (undefined behavior?), OGL w/ copy supports it
    RSC_RTT_MAIN_DEPTHBUFFER_ATTACHABLE = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 11),
    /// Supports attaching a depth buffer to an RTT that has width & height less or equal than RTT's.
    /// Otherwise must be of _exact_ same resolution. D3D 9, OGL 3.0 (not 2.0, not D3D10)
    RSC_RTT_DEPTHBUFFER_RESOLUTION_LESSEQUAL = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 12),
    /// Supports using vertex buffers for instance data
    RSC_VERTEX_BUFFER_INSTANCE_DATA = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 13),
    /// Supports using vertex buffers for instance data
    RSC_CAN_GET_COMPILED_SHADER_BUFFER = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 14),
    /// Supports dynamic linkage/shader subroutine
    RSC_SHADER_SUBROUTINE = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 15),
    
    RSC_HWRENDER_TO_TEXTURE_3D = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 16),
    /// Supports 1d textures
    RSC_TEXTURE_1D              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 17),
    /// Supports hardware tesselation hull programs
    RSC_TESSELATION_HULL_PROGRAM = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 18),
    /// Supports hardware tesselation domain programs
    RSC_TESSELATION_DOMAIN_PROGRAM = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 19),
    /// Supports hardware compute programs
    RSC_COMPUTE_PROGRAM = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 20),
    /// Supports asynchronous hardware occlusion queries
    RSC_HWOCCLUSION_ASYNCHRONOUS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 21),
    /// Supports asynchronous hardware occlusion queries
    RSC_ATOMIC_COUNTERS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_COMMON_2, 22),
    
    // ***** DirectX specific caps *****
    /// Is DirectX feature "per stage constants" supported
    RSC_PERSTAGECONSTANT = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_D3D9, 0),
    
    // ***** GL Specific Caps *****
    /// Supports OpenGL version 1.5
    RSC_GL1_5_NOVBO    = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 1),
    /// Support for Frame Buffer Objects (FBOs)
    RSC_FBO              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 2),
    /// Support for Frame Buffer Objects ARB implementation (regular FBO is higher precedence)
    RSC_FBO_ARB          = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 3),
    /// Support for Frame Buffer Objects ATI implementation (ARB FBO is higher precedence)
    RSC_FBO_ATI          = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 4),
    /// Support for PBuffer
    RSC_PBUFFER          = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 5),
    /// Support for GL 1.5 but without HW occlusion workaround
    RSC_GL1_5_NOHWOCCLUSION = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 6),
    /// Support for point parameters ARB implementation
    RSC_POINT_EXTENDED_PARAMETERS_ARB = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 7),
    /// Support for point parameters EXT implementation
    RSC_POINT_EXTENDED_PARAMETERS_EXT = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 8),
    /// Support for Separate Shader Objects
    RSC_SEPARATE_SHADER_OBJECTS = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 9),
    /// Support for Vertex Array Objects (VAOs)
    RSC_VAO              = OGRE_CAPS_VALUE(CapabilitiesCategory.CAPS_CATEGORY_GL, 10)
}

/// DriverVersion is used by RenderSystemCapabilities and both GL and D3D9
/// to store the version of the current GPU driver
struct DriverVersion
{
    int major;
    int minor;
    int release;
    int build;

    string to(T)() if(is(T == string))
    {
        return std.conv.text(major, ".", minor, ".", release, ".", build);
    }

    string toString()
    {
        return to!string();
    }

    void fromString(string versionString)
    {
        string[] tokens = std.string.split(versionString, ".");
        if(!tokens.empty)
        {
            major = std.conv.parse!int(tokens[0]);
            if (tokens.length > 1)
                minor = std.conv.parse!int(tokens[1]);
            if (tokens.length > 2)
                release = std.conv.parse!int(tokens[2]);
            if (tokens.length > 3)
                build = std.conv.parse!int(tokens[3]);
        }

    }
}

/** Enumeration of GPU vendors. */
enum GPUVendor
{
    GPU_UNKNOWN = 0,
    GPU_NVIDIA = 1,
    GPU_AMD = 2,
    GPU_INTEL = 3,
    GPU_S3 = 4,
    GPU_MATROX = 5,
    GPU_3DLABS = 6,
    GPU_SIS = 7,
    GPU_IMAGINATION_TECHNOLOGIES = 8,
    GPU_APPLE = 9,  // Apple Software Renderer
    GPU_NOKIA = 10,
    GPU_MS_SOFTWARE = 11, // Microsoft software device
    GPU_MS_WARP = 12, // Microsoft WARP (Windows Advanced Rasterization Platform) software device - http://msdn.microsoft.com/en-us/library/dd285359.aspx
    GPU_ARM = 13, // For the Mali chipsets
    GPU_QUALCOMM = 14,

    /// placeholder
    GPU_VENDOR_COUNT = 15
}

/** singleton class for storing the capabilities of the graphics card.
 @remarks
 This class stores the capabilities of the graphics card.  This
 information is set by the individual render systems.
 */
class RenderSystemCapabilities //: public RenderSysAlloc
{

public:

    //typedef set<String>::type ShaderProfiles;
    alias string[] ShaderProfiles;
private:
    /// This is used to build a database of RSC's
    /// if a RSC with same name, but newer version is introduced, the older one
    /// will be removed
    DriverVersion mDriverVersion;
    /// GPU Vendor
    GPUVendor mVendor;

    static StringVector msGPUVendorStrings;
    static void initVendorStrings()
    {
        if (msGPUVendorStrings.empty())
        {
            // Always lower case!
            msGPUVendorStrings.length = GPUVendor.GPU_VENDOR_COUNT;
            msGPUVendorStrings[GPUVendor.GPU_UNKNOWN] = "unknown";
            msGPUVendorStrings[GPUVendor.GPU_NVIDIA] = "nvidia";
            msGPUVendorStrings[GPUVendor.GPU_AMD] = "amd";
            msGPUVendorStrings[GPUVendor.GPU_INTEL] = "intel";
            msGPUVendorStrings[GPUVendor.GPU_3DLABS] = "3dlabs";
            msGPUVendorStrings[GPUVendor.GPU_S3] = "s3";
            msGPUVendorStrings[GPUVendor.GPU_MATROX] = "matrox";
            msGPUVendorStrings[GPUVendor.GPU_SIS] = "sis";
            msGPUVendorStrings[GPUVendor.GPU_IMAGINATION_TECHNOLOGIES] = "imagination technologies";
            msGPUVendorStrings[GPUVendor.GPU_APPLE] = "apple";    // iOS Simulator
            msGPUVendorStrings[GPUVendor.GPU_NOKIA] = "nokia";
            msGPUVendorStrings[GPUVendor.GPU_MS_SOFTWARE] = "microsoft"; // Microsoft software device
            msGPUVendorStrings[GPUVendor.GPU_MS_WARP] = "ms warp";
            msGPUVendorStrings[GPUVendor.GPU_ARM] = "arm";
            msGPUVendorStrings[GPUVendor.GPU_QUALCOMM] = "qualcomm";
        }
    }

    /// The number of world matrices available
    ushort mNumWorldMatrices;
    /// The number of texture units available
    ushort mNumTextureUnits;
    /// The stencil buffer bit depth
    ushort mStencilBufferBitDepth;
    /// The number of matrices available for hardware blending
    ushort mNumVertexBlendMatrices;
    /// Stores the capabilities flags.
    int[CapabilitiesCategory.CAPS_CATEGORY_COUNT] mCapabilities;
    /// Which categories are relevant
    bool[CapabilitiesCategory.CAPS_CATEGORY_COUNT] mCategoryRelevant;
    /// The name of the device as reported by the render system
    string mDeviceName;
    /// The identifier associated with the render system for which these capabilities are valid
    string mRenderSystemName;

    /// The number of floating-point constants vertex programs support
    ushort mVertexProgramConstantFloatCount;
    /// The number of integer constants vertex programs support
    ushort mVertexProgramConstantIntCount;
    /// The number of boolean constants vertex programs support
    ushort mVertexProgramConstantBoolCount;
    /// The number of floating-point constants geometry programs support
    ushort mGeometryProgramConstantFloatCount;
    /// The number of integer constants vertex geometry support
    ushort mGeometryProgramConstantIntCount;
    /// The number of boolean constants vertex geometry support
    ushort mGeometryProgramConstantBoolCount;
    /// The number of floating-point constants fragment programs support
    ushort mFragmentProgramConstantFloatCount;
    /// The number of integer constants fragment programs support
    ushort mFragmentProgramConstantIntCount;
    /// The number of boolean constants fragment programs support
    ushort mFragmentProgramConstantBoolCount;
    /// The number of simultaneous render targets supported
    ushort mNumMultiRenderTargets;
    /// The maximum point size
    Real mMaxPointSize;
    /// Are non-POW2 textures feature-limited?
    bool mNonPOW2TexturesLimited;
    /// The maximum supported anisotropy
    Real mMaxSupportedAnisotropy;
    /// The number of vertex texture units supported
    ushort mNumVertexTextureUnits;
    /// Are vertex texture units shared with fragment processor?
    bool mVertexTextureUnitsShared;
    /// The number of vertices a geometry program can emit in a single run
    int mGeometryProgramNumOutputVertices;

    
    /// The list of supported shader profiles
    ShaderProfiles mSupportedShaderProfiles;

    // Support for new shader stages in shader model 5.0
    /// The number of floating-point constants tesselation Hull programs support
    ushort mTesselationHullProgramConstantFloatCount;
    /// The number of integer constants tesselation Hull programs support
    ushort mTesselationHullProgramConstantIntCount;
    /// The number of boolean constants tesselation Hull programs support
    ushort mTesselationHullProgramConstantBoolCount;
    /// The number of floating-point constants tesselation Domain programs support
    ushort mTesselationDomainProgramConstantFloatCount;
    /// The number of integer constants tesselation Domain programs support
    ushort mTesselationDomainProgramConstantIntCount;
    /// The number of boolean constants tesselation Domain programs support
    ushort mTesselationDomainProgramConstantBoolCount;
    /// The number of floating-point constants compute programs support
    ushort mComputeProgramConstantFloatCount;
    /// The number of integer constants compute programs support
    ushort mComputeProgramConstantIntCount;
    /// The number of boolean constants compute programs support
    ushort mComputeProgramConstantBoolCount;

    

public:
    this ()
    {
        mVendor = GPUVendor.GPU_UNKNOWN;
        mNumWorldMatrices = 0;
        mNumTextureUnits = 0;
        mStencilBufferBitDepth = 0;
        mNumVertexBlendMatrices = 0;
        mNumMultiRenderTargets = 1;
        mNonPOW2TexturesLimited = false;
        mMaxSupportedAnisotropy = 0;
        foreach(i; 0..CapabilitiesCategory.CAPS_CATEGORY_COUNT)
        {
            mCapabilities[i] = 0;
        }
        mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_COMMON] = true;
        mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_COMMON_2] = true;
        // each rendersystem should enable these
        mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_D3D9] = false;
        mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_GL] = false;

        
    }

    ~this () {}

    size_t calculateSize(){return 0;}

    /** Set the driver version. */
    void setDriverVersion(DriverVersion ver)
    {
        mDriverVersion = ver;
    }

    void parseDriverVersionFromString(string versionString)
    {
        DriverVersion ver;
        ver.fromString(versionString);
        setDriverVersion(ver);
    }

    
    DriverVersion getDriverVersion()
    {
        return mDriverVersion;
    }

    GPUVendor getVendor()
    {
        return mVendor;
    }

    void setVendor(GPUVendor v)
    {
        mVendor = v;
    }

    /// Parse and set vendor
    void parseVendorFromString(string vendorString)
    {
        setVendor(vendorFromString(vendorString));
    }

    /// Convert a vendor string to an enum
    static GPUVendor vendorFromString(string vendorString)
    {
        initVendorStrings();
        GPUVendor ret = GPUVendor.GPU_UNKNOWN;
        string cmpString = std.string.toLower(vendorString);

        foreach (i; GPUVendor.GPU_UNKNOWN..GPUVendor.GPU_VENDOR_COUNT)
        {
            // case insensitive (lower case)
            if (msGPUVendorStrings[i] == cmpString)
            {
                ret = i;
                break;
            }
        }

        return ret;

    }

    /// Convert a vendor enum to a string
    static string vendorToString(GPUVendor v)
    {
        initVendorStrings();
        return msGPUVendorStrings[v];
    }

    bool isDriverOlderThanVersion(DriverVersion v)
    {
        if (mDriverVersion.major < v.major)
            return true;
        else if (mDriverVersion.major == v.major &&
                 mDriverVersion.minor < v.minor)
            return true;
        else if (mDriverVersion.major == v.major &&
                 mDriverVersion.minor == v.minor &&
                 mDriverVersion.release < v.release)
            return true;
        else if (mDriverVersion.major == v.major &&
                 mDriverVersion.minor == v.minor &&
                 mDriverVersion.release == v.release &&
                 mDriverVersion.build < v.build)
            return true;
        return false;
    }

    void setNumWorldMatrices(ushort num)
    {
        mNumWorldMatrices = num;
    }

    void setNumTextureUnits(ushort num)
    {
        mNumTextureUnits = num;
    }

    void setStencilBufferBitDepth(ushort num)
    {
        mStencilBufferBitDepth = num;
    }

    void setNumVertexBlendMatrices(ushort num)
    {
        mNumVertexBlendMatrices = num;
    }

    /// The number of simultaneous render targets supported
    void setNumMultiRenderTargets(ushort num)
    {
        mNumMultiRenderTargets = num;
    }

    ushort getNumWorldMatrices()
    {
        return mNumWorldMatrices;
    }

    /** Returns the number of texture units the current output hardware
     supports.

     For use in rendering, this determines how many texture units the
     are available for multitexturing (i.e. rendering multiple
     textures in a single pass). Where a Material has multiple
     texture layers, it will try to use multitexturing where
     available, and where it is not available, will perform multipass
     rendering to achieve the same effect. This property only applies
     to the fixed-function pipeline, the number available to the
     programmable pipeline depends on the shader model in use.
     */
    ushort getNumTextureUnits()
    {
        return mNumTextureUnits;
    }

    /** Determines the bit depth of the hardware accelerated stencil
     buffer, if supported.
     @remarks
     If hardware stencilling is not supported, the software will
     provide an 8-bit software stencil.
     */
    ushort getStencilBufferBitDepth()
    {
        return mStencilBufferBitDepth;
    }

    /** Returns the number of matrices available to hardware vertex
     blending for this rendering system. */
    ushort getNumVertexBlendMatrices()
    {
        return mNumVertexBlendMatrices;
    }

    /// The number of simultaneous render targets supported
    ushort getNumMultiRenderTargets()
    {
        return mNumMultiRenderTargets;
    }

    /** Returns true if capability is render system specific
     */
    bool isCapabilityRenderSystemSpecific(Capabilities c)
    {
        int cat = c >> OGRE_CAPS_BITSHIFT;
        if(cat == CapabilitiesCategory.CAPS_CATEGORY_GL || cat == CapabilitiesCategory.CAPS_CATEGORY_D3D9)
            return true;
        return false;
    }

    /** Adds a capability flag
     */
    void setCapability(Capabilities c)
    {
        int index = (CAPS_CATEGORY_MASK & c) >> OGRE_CAPS_BITSHIFT;
        // zero out the index from the stored capability
        mCapabilities[index] |= (c & ~CAPS_CATEGORY_MASK);
    }

    /** Remove a capability flag
     */
    void unsetCapability(Capabilities c)
    {
        int index = (CAPS_CATEGORY_MASK & c) >> OGRE_CAPS_BITSHIFT;
        // zero out the index from the stored capability
        mCapabilities[index] &= (~c | CAPS_CATEGORY_MASK);
    }

    /** Checks for a capability
     */
    bool hasCapability(Capabilities c)
    {
        int index = (CAPS_CATEGORY_MASK & c) >> OGRE_CAPS_BITSHIFT;
        // test against
        if(mCapabilities[index] & (c & ~CAPS_CATEGORY_MASK))
        {
            return true;
        }
        else
        {
            return false;
        }
    }

    /** Adds the profile to the list of supported profiles
     */
    void addShaderProfile(string profile)
    {
        mSupportedShaderProfiles.insert(profile);
    }

    /** Remove a given shader profile, if present.
     */
    void removeShaderProfile(string profile)
    {
        mSupportedShaderProfiles.removeFromArray(profile);
    }

    /** Returns true if profile is in the list of supported profiles
     */
    bool isShaderProfileSupported(string profile)
    {
        return inArray(mSupportedShaderProfiles, profile);
    }

    
    /** Returns a set of all supported shader profiles
     * */
    ref ShaderProfiles getSupportedShaderProfiles()
    {
        return mSupportedShaderProfiles;
    }

    
    /// The number of floating-point constants vertex programs support
    ushort getVertexProgramConstantFloatCount()
    {
        return mVertexProgramConstantFloatCount;
    }
    /// The number of integer constants vertex programs support
    ushort getVertexProgramConstantIntCount()
    {
        return mVertexProgramConstantIntCount;
    }
    /// The number of boolean constants vertex programs support
    ushort getVertexProgramConstantBoolCount()
    {
        return mVertexProgramConstantBoolCount;
    }
    /// The number of floating-point constants geometry programs support
    ushort getGeometryProgramConstantFloatCount()
    {
        return mGeometryProgramConstantFloatCount;
    }
    /// The number of integer constants geometry programs support
    ushort getGeometryProgramConstantIntCount()
    {
        return mGeometryProgramConstantIntCount;
    }
    /// The number of boolean constants geometry programs support
    ushort getGeometryProgramConstantBoolCount()
    {
        return mGeometryProgramConstantBoolCount;
    }
    /// The number of floating-point constants fragment programs support
    ushort getFragmentProgramConstantFloatCount()
    {
        return mFragmentProgramConstantFloatCount;
    }
    /// The number of integer constants fragment programs support
    ushort getFragmentProgramConstantIntCount()
    {
        return mFragmentProgramConstantIntCount;
    }
    /// The number of boolean constants fragment programs support
    ushort getFragmentProgramConstantBoolCount()
    {
        return mFragmentProgramConstantBoolCount;
    }

    /// sets the device name for Render system
    void setDeviceName(string name)
    {
        mDeviceName = name;
    }

    /// gets the device name for render system
    string getDeviceName()
    {
        return mDeviceName;
    }

    /// The number of floating-point constants vertex programs support
    void setVertexProgramConstantFloatCount(ushort c)
    {
        mVertexProgramConstantFloatCount = c;
    }
    /// The number of integer constants vertex programs support
    void setVertexProgramConstantIntCount(ushort c)
    {
        mVertexProgramConstantIntCount = c;
    }
    /// The number of boolean constants vertex programs support
    void setVertexProgramConstantBoolCount(ushort c)
    {
        mVertexProgramConstantBoolCount = c;
    }
    /// The number of floating-point constants geometry programs support
    void setGeometryProgramConstantFloatCount(ushort c)
    {
        mGeometryProgramConstantFloatCount = c;
    }
    /// The number of integer constants geometry programs support
    void setGeometryProgramConstantIntCount(ushort c)
    {
        mGeometryProgramConstantIntCount = c;
    }
    /// The number of boolean constants geometry programs support
    void setGeometryProgramConstantBoolCount(ushort c)
    {
        mGeometryProgramConstantBoolCount = c;
    }
    /// The number of floating-point constants fragment programs support
    void setFragmentProgramConstantFloatCount(ushort c)
    {
        mFragmentProgramConstantFloatCount = c;
    }
    /// The number of integer constants fragment programs support
    void setFragmentProgramConstantIntCount(ushort c)
    {
        mFragmentProgramConstantIntCount = c;
    }
    /// The number of boolean constants fragment programs support
    void setFragmentProgramConstantBoolCount(ushort c)
    {
        mFragmentProgramConstantBoolCount = c;
    }
    /// Maximum point screen size in pixels
    void setMaxPointSize(Real s)
    {
        mMaxPointSize = s;
    }
    /// Maximum point screen size in pixels
    Real getMaxPointSize()
    {
        return mMaxPointSize;
    }
    /// Non-POW2 textures limited
    void setNonPOW2TexturesLimited(bool l)
    {
        mNonPOW2TexturesLimited = l;
    }
    /** Are non-power of two textures limited in features?
     @remarks
     If the RSC_NON_POWER_OF_2_TEXTURES capability is set, but this
     method returns true, you can use non power of 2 textures only if:
     <ul><li>You load them explicitly with no mip maps</li>
     <li>You don't use DXT texture compression</li>
     <li>You use clamp texture addressing</li></ul>
     */
    bool getNonPOW2TexturesLimited()
    {
        return mNonPOW2TexturesLimited;
    }
    /// Set the maximum supported anisotropic filtering
    void setMaxSupportedAnisotropy(Real s)
    {
        mMaxSupportedAnisotropy = s;
    }
    /// Get the maximum supported anisotropic filtering
    Real getMaxSupportedAnisotropy()
    {
        return mMaxSupportedAnisotropy;
    }

    /// Set the number of vertex texture units supported
    void setNumVertexTextureUnits(ushort n)
    {
        mNumVertexTextureUnits = n;
    }
    /// Get the number of vertex texture units supported
    ushort getNumVertexTextureUnits()
    {
        return mNumVertexTextureUnits;
    }
    /// Set whether the vertex texture units are shared with the fragment processor
    void setVertexTextureUnitsShared(bool _shared)
    {
        mVertexTextureUnitsShared = _shared;
    }
    /// Get whether the vertex texture units are shared with the fragment processor
    bool getVertexTextureUnitsShared()
    {
        return mVertexTextureUnitsShared;
    }

    /// Set the number of vertices a single geometry program run can emit
    void setGeometryProgramNumOutputVertices(int numOutputVertices)
    {
        mGeometryProgramNumOutputVertices = numOutputVertices;
    }
    /// Get the number of vertices a single geometry program run can emit
    int getGeometryProgramNumOutputVertices()
    {
        return mGeometryProgramNumOutputVertices;
    }

    /// Get the identifier of the rendersystem from which these capabilities were generated
    string getRenderSystemName()
    {
        return mRenderSystemName;
    }
    ///  Set the identifier of the rendersystem from which these capabilities were generated
    void setRenderSystemName(string rs)
    {
        mRenderSystemName = rs;
    }

    /// Mark a category as 'relevant' or not, ie will it be reported
    void setCategoryRelevant(CapabilitiesCategory cat, bool relevant)
    {
        mCategoryRelevant[cat] = relevant;
    }

    /// Return whether a category is 'relevant' or not, ie will it be reported
    bool isCategoryRelevant(CapabilitiesCategory cat)
    {
        return mCategoryRelevant[cat];
    }

    

    /** Write the capabilities to the pass in Log */
    void log(ref Log pLog)
    {
        //#if OGRE_PLATFORM != OGRE_PLATFORM_WINRT
        pLog.logMessage("RenderSystem capabilities");
        pLog.logMessage("-------------------------");
        pLog.logMessage("RenderSystem Name: " ~ getRenderSystemName());
        pLog.logMessage("GPU Vendor: " ~ vendorToString(getVendor()));
        pLog.logMessage("Device Name: " ~ getDeviceName());
        pLog.logMessage("Driver Version: " ~ getDriverVersion().toString());
        pLog.logMessage(" * Fixed function pipeline: " 
                        ~ .to!string(hasCapability(Capabilities.RSC_FIXED_FUNCTION)));
        pLog.logMessage(
            " * Hardware generation of mipmaps: "
            ~ .to!string(hasCapability(Capabilities.RSC_AUTOMIPMAP)));
        pLog.logMessage(
            " * Texture blending: "
            ~ .to!string(hasCapability(Capabilities.RSC_BLENDING)));
        pLog.logMessage(
            " * Anisotropic texture filtering: "
            ~ .to!string(hasCapability(Capabilities.RSC_ANISOTROPY)));
        pLog.logMessage(
            " * Dot product texture operation: "
            ~ .to!string(hasCapability(Capabilities.RSC_DOT3)));
        pLog.logMessage(
            " * Cube mapping: "
            ~ .to!string(hasCapability(Capabilities.RSC_CUBEMAPPING)));
        pLog.logMessage(
            " * Hardware stencil buffer: "
            ~ .to!string(hasCapability(Capabilities.RSC_HWSTENCIL)));
        if (hasCapability(Capabilities.RSC_HWSTENCIL))
        {
            pLog.logMessage(
                "   - Stencil depth: "
                ~ .to!string(getStencilBufferBitDepth()));
            pLog.logMessage(
                "   - Two sided stencil support: "
                ~ .to!string(hasCapability(Capabilities.RSC_TWO_SIDED_STENCIL)));
            pLog.logMessage(
                "   - Wrap stencil values: "
                ~ .to!string(hasCapability(Capabilities.RSC_STENCIL_WRAP)));
        }
        pLog.logMessage(
            " * Hardware vertex / index buffers: "
            ~ .to!string(hasCapability(Capabilities.RSC_VBO)));
        pLog.logMessage(
            " * Vertex programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_VERTEX_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for vertex programs: "
            ~ .to!string(mVertexProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for vertex programs: "
            ~ .to!string(mVertexProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for vertex programs: "
            ~ .to!string(mVertexProgramConstantBoolCount));
        pLog.logMessage(
            " * Fragment programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_FRAGMENT_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for fragment programs: "
            ~ .to!string(mFragmentProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for fragment programs: "
            ~ .to!string(mFragmentProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for fragment programs: "
            ~ .to!string(mFragmentProgramConstantBoolCount));
        pLog.logMessage(
            " * Geometry programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_GEOMETRY_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for geometry programs: "
            ~ .to!string(mGeometryProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for geometry programs: "
            ~ .to!string(mGeometryProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for geometry programs: "
            ~ .to!string(mGeometryProgramConstantBoolCount));
        pLog.logMessage(
            " * Tesselation Hull programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_TESSELATION_HULL_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for tesselation hull programs: "
            ~ .to!string(mTesselationHullProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for tesselation hull programs: "
            ~ .to!string(mTesselationHullProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for tesselation hull programs: "
            ~ .to!string(mTesselationHullProgramConstantBoolCount));
        pLog.logMessage(
            " * Tesselation Domain programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_TESSELATION_DOMAIN_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for tesselation domain programs: "
            ~ .to!string(mTesselationDomainProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for tesselation domain programs: "
            ~ .to!string(mTesselationDomainProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for tesselation domain programs: "
            ~ .to!string(mTesselationDomainProgramConstantBoolCount));
        pLog.logMessage(
            " * Compute programs: "
            ~ .to!string(hasCapability(Capabilities.RSC_COMPUTE_PROGRAM)));
        pLog.logMessage(
            " * Number of floating-point constants for compute programs: "
            ~ .to!string(mComputeProgramConstantFloatCount));
        pLog.logMessage(
            " * Number of integer constants for compute programs: "
            ~ .to!string(mComputeProgramConstantIntCount));
        pLog.logMessage(
            " * Number of boolean constants for compute programs: "
            ~ .to!string(mComputeProgramConstantBoolCount));
        string profileList = "";
        foreach(profile; mSupportedShaderProfiles)
        {
            profileList ~= " " ~ profile;
        }
        pLog.logMessage(" * Supported Shader Profiles:" ~ profileList);
        
        pLog.logMessage(
            " * Texture Compression: "
            ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION)));
        if (hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION))
        {
            pLog.logMessage(
                "   - DXT: "
                ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_DXT)));
            pLog.logMessage(
                "   - VTC: "
                ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_VTC)));
            pLog.logMessage(
                "   - PVRTC: "
                ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_PVRTC)));
            pLog.logMessage(
                "   - BC4/BC5: "
                ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_BC4_BC5)));
            pLog.logMessage(
                "   - BC6H/BC7: "
                ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_BC6H_BC7)));
        }
        
        pLog.logMessage(
            " * Scissor Rectangle: "
            ~ .to!string(hasCapability(Capabilities.RSC_SCISSOR_TEST)));
        pLog.logMessage(
            " * Hardware Occlusion Query: "
            ~ .to!string(hasCapability(Capabilities.RSC_HWOCCLUSION)));
        pLog.logMessage(
            " * User clip planes: "
            ~ .to!string(hasCapability(Capabilities.RSC_USER_CLIP_PLANES)));
        pLog.logMessage(
            " * VertexElementType.VET_UBYTE4 vertex element type: "
            ~ .to!string(hasCapability(Capabilities.RSC_VERTEX_FORMAT_UBYTE4)));
        pLog.logMessage(
            " * Infinite far plane projection: "
            ~ .to!string(hasCapability(Capabilities.RSC_INFINITE_FAR_PLANE)));
        pLog.logMessage(
            " * Hardware render-to-texture: "
            ~ .to!string(hasCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE)));
        pLog.logMessage(
            " * Floating point textures: "
            ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_FLOAT)));
        pLog.logMessage(
            " * Non-power-of-two textures: "
            ~ .to!string(hasCapability(Capabilities.RSC_NON_POWER_OF_2_TEXTURES))
            ~ (mNonPOW2TexturesLimited ? " (limited)" : ""));
        pLog.logMessage(
            " * 1d textures: "
            ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_1D)));
        pLog.logMessage(
            " * Volume textures: "
            ~ .to!string(hasCapability(Capabilities.RSC_TEXTURE_3D)));
        pLog.logMessage(
            " * Multiple Render Targets: "
            ~ .to!string(mNumMultiRenderTargets));
        pLog.logMessage(
            "   - With different bit depths: " ~ .to!string(hasCapability(Capabilities.RSC_MRT_DIFFERENT_BIT_DEPTHS)));
        pLog.logMessage(
            " * Point Sprites: "
            ~ .to!string(hasCapability(Capabilities.RSC_POINT_SPRITES)));
        pLog.logMessage(
            " * Extended point parameters: "
            ~ .to!string(hasCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS)));
        if(hasCapability(Capabilities.RSC_POINT_SPRITES))
        {
            pLog.logMessage(
                " * Max Point Size: "
                ~ .to!string(mMaxPointSize));
        }
        pLog.logMessage(
            " * Vertex texture fetch: "
            ~ .to!string(hasCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH)));
        pLog.logMessage(
            " * Number of world matrices: "
            ~ .to!string(mNumWorldMatrices));
        pLog.logMessage(
            " * Number of texture units: "
            ~ .to!string(mNumTextureUnits));
        pLog.logMessage(
            " * Stencil buffer depth: "
            ~ .to!string(mStencilBufferBitDepth));
        pLog.logMessage(
            " * Number of vertex blend matrices: "
            ~ .to!string(mNumVertexBlendMatrices));
        if (hasCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH))
        {
            pLog.logMessage(
                "   - Max vertex textures: "
                ~ .to!string(mNumVertexTextureUnits));
            pLog.logMessage(
                "   - Vertex textures shared: "
                ~ .to!string(mVertexTextureUnitsShared));
            
        }
        pLog.logMessage(
            " * Render to Vertex Buffer : "
            ~ .to!string(hasCapability(Capabilities.RSC_HWRENDER_TO_VERTEX_BUFFER)));
        pLog.logMessage(
            " * Hardware Atomic Counters: "
            ~ .to!string(hasCapability(Capabilities.RSC_ATOMIC_COUNTERS)));
        
        if (mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_GL])
        {
            pLog.logMessage(
                " * GL 1.5 without VBO workaround: "
                ~ .to!string(hasCapability(Capabilities.RSC_GL1_5_NOVBO)));
            
            pLog.logMessage(
                " * Frame Buffer objects: "
                ~ .to!string(hasCapability(Capabilities.RSC_FBO)));
            pLog.logMessage(
                " * Frame Buffer objects (ARB extension): "
                ~ .to!string(hasCapability(Capabilities.RSC_FBO_ARB)));
            pLog.logMessage(
                " * Frame Buffer objects (ATI extension): "
                ~ .to!string(hasCapability(Capabilities.RSC_FBO_ATI)));
            pLog.logMessage(
                " * PBuffer support: "
                ~ .to!string(hasCapability(Capabilities.RSC_PBUFFER)));
            pLog.logMessage(
                " * GL 1.5 without HW-occlusion workaround: "
                ~ .to!string(hasCapability(Capabilities.RSC_GL1_5_NOHWOCCLUSION)));
            pLog.logMessage(
                " * Vertex Array Objects: "
                ~ .to!string(hasCapability(Capabilities.RSC_VAO)));
            pLog.logMessage(
                " * Separate shader objects: "
                ~ .to!string(hasCapability(Capabilities.RSC_SEPARATE_SHADER_OBJECTS)));
        }
        
        if (mCategoryRelevant[CapabilitiesCategory.CAPS_CATEGORY_D3D9])
        {
            pLog.logMessage(
                " * DirectX per stage constants: "
                ~ .to!string(hasCapability(Capabilities.RSC_PERSTAGECONSTANT)));
        }
        //#endif
    }

    // Support for new shader stages in shader model 5.0
    /// The number of floating-point constants tesselation Hull programs support
    void setTesselationHullProgramConstantFloatCount(ushort c)
    {
        mTesselationHullProgramConstantFloatCount = c;
    }
    /// The number of integer constants tesselation Domain programs support
    void setTesselationHullProgramConstantIntCount(ushort c)
    {
        mTesselationHullProgramConstantIntCount = c;
    }
    /// The number of boolean constants tesselation Domain programs support
    void setTesselationHullProgramConstantBoolCount(ushort c)
    {
        mTesselationHullProgramConstantBoolCount = c;
    }
    /// The number of floating-point constants fragment programs support
    ushort getTesselationHullProgramConstantFloatCount()
    {
        return mTesselationHullProgramConstantFloatCount;
    }
    /// The number of integer constants fragment programs support
    ushort getTesselationHullProgramConstantIntCount()
    {
        return mTesselationHullProgramConstantIntCount;
    }
    /// The number of boolean constants fragment programs support
    ushort getTesselationHullProgramConstantBoolCount()
    {
        return mTesselationHullProgramConstantBoolCount;
    }

    /// The number of floating-point constants tesselation Domain programs support
    void setTesselationDomainProgramConstantFloatCount(ushort c)
    {
        mTesselationDomainProgramConstantFloatCount = c;
    }
    /// The number of integer constants tesselation Domain programs support
    void setTesselationDomainProgramConstantIntCount(ushort c)
    {
        mTesselationDomainProgramConstantIntCount = c;
    }
    /// The number of boolean constants tesselation Domain programs support
    void setTesselationDomainProgramConstantBoolCount(ushort c)
    {
        mTesselationDomainProgramConstantBoolCount = c;
    }
    /// The number of floating-point constants fragment programs support
    ushort getTesselationDomainProgramConstantFloatCount()
    {
        return mTesselationDomainProgramConstantFloatCount;
    }
    /// The number of integer constants fragment programs support
    ushort getTesselationDomainProgramConstantIntCount()
    {
        return mTesselationDomainProgramConstantIntCount;
    }
    /// The number of boolean constants fragment programs support
    ushort getTesselationDomainProgramConstantBoolCount()
    {
        return mTesselationDomainProgramConstantBoolCount;
    }

    /// The number of floating-point constants compute programs support
    void setComputeProgramConstantFloatCount(ushort c)
    {
        mComputeProgramConstantFloatCount = c;
    }
    /// The number of integer constants compute programs support
    void setComputeProgramConstantIntCount(ushort c)
    {
        mComputeProgramConstantIntCount = c;
    }
    /// The number of boolean constants compute programs support
    void setComputeProgramConstantBoolCount(ushort c)
    {
        mComputeProgramConstantBoolCount = c;
    }
    /// The number of floating-point constants fragment programs support
    ushort getComputeProgramConstantFloatCount()
    {
        return mComputeProgramConstantFloatCount;
    }
    /// The number of integer constants fragment programs support
    ushort getComputeProgramConstantIntCount()
    {
        return mComputeProgramConstantIntCount;
    }
    /// The number of boolean constants fragment programs support
    ushort getComputeProgramConstantBoolCount()
    {
        return mComputeProgramConstantBoolCount;
    }

}

/** Class for managing RenderSystemCapabilities database for Ogre.
 @remarks This class behaves similarly to other ResourceManager, although .rendercaps are not resources.
 It contains and abstract a .rendercaps Serializer
 */
final class RenderSystemCapabilitiesManager //:  public Singleton<RenderSystemCapabilitiesManager>, public RenderSysAlloc
{
    mixin Singleton!RenderSystemCapabilitiesManager;
    
public:
    
    /** Default constructor.
     @note Use getSingleton() instead.
     */
    this()
    {
        //mSerializer = null;
        mScriptPattern = "*.rendercaps";
        mSerializer = new RenderSystemCapabilitiesSerializer();
    }
    
    /** Default destructor.
     */
    ~this()
    {
        foreach (k,v; mCapabilitiesMap)
        {
            // free memory in RenderSystemCapabilities*
            destroy(v);
        }
        
        destroy(mSerializer);
    }
    
    
    
    /** @see ScriptLoader::parseScript
     */
    void parseCapabilitiesFromArchive(string filename,string archiveType, bool recursive = true)
    {
        // get the list of .rendercaps files
        Archive arch = ArchiveManager.getSingleton().load(filename, archiveType, true);
        StringVector files = arch.find(mScriptPattern, recursive);
        
        // loop through .rendercaps files and load each one
        foreach (it; files)
        {
            DataStream stream = arch.open(it);
            mSerializer.parseScript(stream);
            stream.close();
        }
    }
    
    /** Returns a capability loaded with RenderSystemCapabilitiesManager::parseCapabilitiesFromArchive method
     * @return NULL if the name is invalid, a parsed RenderSystemCapabilities otherwise.
     */
    ref RenderSystemCapabilities loadParsedCapabilities(string name)
    {
        return mCapabilitiesMap[name];
    }
    
    /** Access to the internal map of loaded capabilities */
    //map<String, RenderSystemCapabilities*>::type &getCapabilities();
    ref CapabilitiesMap getCapabilities()
    {
        return mCapabilitiesMap;
    }
    
    /** Method used by RenderSystemCapabilitiesSerializer::parseScript */
    void _addRenderSystemCapabilities(string name, RenderSystemCapabilities caps)
    {
        // TODO Don't add if already exists?
        //if((name in mCapabilitiesMap) !is null) return; 
        mCapabilitiesMap[name] = caps;
    }
    
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    
    //static RenderSystemCapabilitiesManager& getSingleton();
    /** Override standard Singleton retrieval.
     @remarks
     Why do we do this? Well, it's because the Singleton
     implementation is in a .h file, which means it gets compiled
     into anybody who includes it. This is needed for the
     Singleton template to work, but we actually only want it
     compiled into the implementation of the class based on the
     Singleton, not all of them. If we don't change this, we get
     link errors when trying to use the Singleton-based class from
     an outside dll.
     @par
     This method just delegates to the template version anyway,
     but the implementation stays in this single compilation unit,
     preventing link errors.
     */
    //static RenderSystemCapabilitiesManager* getSingletonPtr();
    
protected:
    
    RenderSystemCapabilitiesSerializer mSerializer;
    
    //typedef map<String, RenderSystemCapabilities*>::type CapabilitiesMap;
    alias RenderSystemCapabilities[string] CapabilitiesMap;
    CapabilitiesMap mCapabilitiesMap;
    
    string mScriptPattern;
    
}

/** Class for serializing RenderSystemCapabilities to / from a .rendercaps script.*/
class RenderSystemCapabilitiesSerializer //: public RenderSysAlloc
{
    
public:
    /** defaultructor*/
    this()
    {
        mCurrentLineNumber = 0;
        mCurrentLine = null;
        mCurrentCapabilities = null;
        //mCurrentStream.setNull();
        
        initialiaseDispatchTables(this);
    }
    
    /** default destructor*/
    ~this() {}

    static void write(RenderSystemCapabilities caps, string name, DataStream file)
    {
        file.write(text("render_system_capabilities \"", name, "\"\n"));
        file.write("{");
        
        file.write(text("\trender_system_name ", caps.getRenderSystemName(), "\n"));
        file.write("\n");
        
        
        file.write(text("\tdevice_name ", caps.getDeviceName(), "\n"));
        DriverVersion driverVer = caps.getDriverVersion();
        file.write(text("\tdriver_version ", driverVer.toString(), "\n"));
        file.write(text("\tvendor ", caps.vendorToString(caps.getVendor()), "\n")); 
        file.write("\n");
        file.write("\n");
        file.write(text("\tfixed_function ", caps.hasCapability(Capabilities.RSC_FIXED_FUNCTION), "\n"));
        file.write(text("\tautomipmap ", caps.hasCapability(Capabilities.RSC_AUTOMIPMAP), "\n"));
        file.write(text("\tblending ", caps.hasCapability(Capabilities.RSC_BLENDING), "\n"));
        file.write(text("\tanisotropy ", caps.hasCapability(Capabilities.RSC_ANISOTROPY), "\n"));
        file.write(text("\tdot3 ", caps.hasCapability(Capabilities.RSC_DOT3), "\n"));
        file.write(text("\tcubemapping ", caps.hasCapability(Capabilities.RSC_CUBEMAPPING), "\n"));
        file.write(text("\thwstencil ", caps.hasCapability(Capabilities.RSC_HWSTENCIL), "\n"));
        file.write(text("\tvbo ", caps.hasCapability(Capabilities.RSC_VBO), "\n"));
        file.write(text("\tvertex_program ", caps.hasCapability(Capabilities.RSC_VERTEX_PROGRAM), "\n"));
        file.write(text("\tfragment_program ", caps.hasCapability(Capabilities.RSC_FRAGMENT_PROGRAM), "\n"));
        file.write(text("\tgeometry_program ", caps.hasCapability(Capabilities.RSC_GEOMETRY_PROGRAM), "\n"));
        file.write(text("\ttesselation_hull_program ", caps.hasCapability(Capabilities.RSC_TESSELATION_HULL_PROGRAM), "\n"));
        file.write(text("\ttesselation_domain_program ", caps.hasCapability(Capabilities.RSC_TESSELATION_DOMAIN_PROGRAM), "\n"));
        file.write(text("\tcompute_program ", caps.hasCapability(Capabilities.RSC_COMPUTE_PROGRAM), "\n"));
        file.write(text("\tscissor_test ", caps.hasCapability(Capabilities.RSC_SCISSOR_TEST), "\n"));
        file.write(text("\ttwo_sided_stencil ", caps.hasCapability(Capabilities.RSC_TWO_SIDED_STENCIL), "\n"));
        file.write(text("\tstencil_wrap ", caps.hasCapability(Capabilities.RSC_STENCIL_WRAP), "\n"));
        file.write(text("\thwocclusion ", caps.hasCapability(Capabilities.RSC_HWOCCLUSION), "\n"));
        file.write(text("\tuser_clip_planes ", caps.hasCapability(Capabilities.RSC_USER_CLIP_PLANES), "\n"));
        file.write(text("\tvertex_format_ubyte4 ", caps.hasCapability(Capabilities.RSC_VERTEX_FORMAT_UBYTE4), "\n"));
        file.write(text("\tinfinite_far_plane ", caps.hasCapability(Capabilities.RSC_INFINITE_FAR_PLANE), "\n"));
        file.write(text("\thwrender_to_texture ", caps.hasCapability(Capabilities.RSC_HWRENDER_TO_TEXTURE), "\n"));
        file.write(text("\ttexture_float ", caps.hasCapability(Capabilities.RSC_TEXTURE_FLOAT), "\n"));
        file.write(text("\tnon_power_of_2_textures ", caps.hasCapability(Capabilities.RSC_NON_POWER_OF_2_TEXTURES), "\n"));
        file.write(text("\ttexture_3d ", caps.hasCapability(Capabilities.RSC_TEXTURE_3D), "\n"));
        file.write(text("\ttexture_1d ", caps.hasCapability(Capabilities.RSC_TEXTURE_1D), "\n"));
        file.write(text("\tpoint_sprites ", caps.hasCapability(Capabilities.RSC_POINT_SPRITES), "\n"));
        file.write(text("\tpoint_extended_parameters ", caps.hasCapability(Capabilities.RSC_POINT_EXTENDED_PARAMETERS), "\n"));
        file.write(text("\tvertex_texture_fetch ", caps.hasCapability(Capabilities.RSC_VERTEX_TEXTURE_FETCH), "\n"));
        file.write(text("\tmipmap_lod_bias ", caps.hasCapability(Capabilities.RSC_MIPMAP_LOD_BIAS), "\n"));
        file.write(text("\tatomic_counters ", caps.hasCapability(Capabilities.RSC_ATOMIC_COUNTERS), "\n"));
        file.write(text("\ttexture_compression ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION), "\n"));
        file.write(text("\ttexture_compression_dxt ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_DXT), "\n"));
        file.write(text("\ttexture_compression_vtc ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_VTC), "\n"));
        file.write(text("\ttexture_compression_pvrtc ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_PVRTC), "\n"));
        file.write(text("\ttexture_compression_bc4_bc5 ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_BC4_BC5), "\n"));
        file.write(text("\ttexture_compression_bc6h_bc7 ", caps.hasCapability(Capabilities.RSC_TEXTURE_COMPRESSION_BC6H_BC7), "\n"));
        file.write(text("\tgl1_5_novbo ", caps.hasCapability(Capabilities.RSC_GL1_5_NOVBO), "\n"));
        file.write(text("\tfbo ", caps.hasCapability(Capabilities.RSC_FBO), "\n"));
        file.write(text("\tfbo_arb ", caps.hasCapability(Capabilities.RSC_FBO_ARB), "\n"));
        file.write(text("\tfbo_ati ", caps.hasCapability(Capabilities.RSC_FBO_ATI), "\n"));
        file.write(text("\tpbuffer ", caps.hasCapability(Capabilities.RSC_PBUFFER), "\n"));
        file.write(text("\tgl1_5_nohwocclusion ", caps.hasCapability(Capabilities.RSC_GL1_5_NOHWOCCLUSION), "\n"));
        file.write(text("\tperstageconstant ", caps.hasCapability(Capabilities.RSC_PERSTAGECONSTANT), "\n"));
        file.write(text("\tvao ", caps.hasCapability(Capabilities.RSC_VAO), "\n"));
        file.write(text("\tseparate_shader_objects ", caps.hasCapability(Capabilities.RSC_SEPARATE_SHADER_OBJECTS), "\n"));
        file.write("\n");

        // write every profile
        foreach(it; caps.getSupportedShaderProfiles())
        {
            file.write(text("\tshader_profile ", it, "\n"));
        }
        
        file.write("\n");
        file.write(text("\tmax_point_size ", caps.getMaxPointSize(), "\n"));
        
        file.write("\n");
        file.write(text("\tnon_pow2_textures_limited ", caps.getNonPOW2TexturesLimited(), "\n"));
        file.write(text("\tvertex_texture_units_shared ", caps.getVertexTextureUnitsShared(), "\n"));
        
        file.write("\n");
        file.write(text("\tnum_world_matrices ", caps.getNumWorldMatrices(), "\n"));
        file.write(text("\tnum_texture_units ", caps.getNumTextureUnits(), "\n"));
        file.write(text("\tstencil_buffer_bit_depth ", caps.getStencilBufferBitDepth(), "\n"));
        file.write(text("\tnum_vertex_blend_matrices ", caps.getNumVertexBlendMatrices(), "\n"));
        file.write(text("\tnum_multi_render_targets ", caps.getNumMultiRenderTargets(), "\n"));
        file.write(text("\tvertex_program_constant_float_count ", caps.getVertexProgramConstantFloatCount(), "\n"));
        file.write(text("\tvertex_program_constant_int_count ", caps.getVertexProgramConstantIntCount(), "\n"));
        file.write(text("\tvertex_program_constant_bool_count ", caps.getVertexProgramConstantBoolCount(), "\n"));
        file.write(text("\tfragment_program_constant_float_count ", caps.getFragmentProgramConstantFloatCount(), "\n"));
        file.write(text("\tfragment_program_constant_int_count ", caps.getFragmentProgramConstantIntCount(), "\n"));
        file.write(text("\tfragment_program_constant_bool_count ", caps.getFragmentProgramConstantBoolCount(), "\n"));
        file.write(text("\tgeometry_program_constant_float_count ", caps.getGeometryProgramConstantFloatCount(), "\n"));
        file.write(text("\tgeometry_program_constant_int_count ", caps.getGeometryProgramConstantIntCount(), "\n"));
        file.write(text("\tgeometry_program_constant_bool_count ", caps.getGeometryProgramConstantBoolCount(), "\n"));
        file.write(text("\ttesselation_hull_program_constant_float_count ", caps.getTesselationHullProgramConstantFloatCount(), "\n"));
        file.write(text("\ttesselation_hull_program_constant_int_count ", caps.getTesselationHullProgramConstantIntCount(), "\n"));
        file.write(text("\ttesselation_hull_program_constant_bool_count ", caps.getTesselationHullProgramConstantBoolCount(), "\n"));
        file.write(text("\ttesselation_domain_program_constant_float_count ", caps.getTesselationDomainProgramConstantFloatCount(), "\n"));
        file.write(text("\ttesselation_domain_program_constant_int_count ", caps.getTesselationDomainProgramConstantIntCount(), "\n"));
        file.write(text("\ttesselation_domain_program_constant_bool_count ", caps.getTesselationDomainProgramConstantBoolCount(), "\n"));
        file.write(text("\tcompute_program_constant_float_count ", caps.getComputeProgramConstantFloatCount(), "\n"));
        file.write(text("\tcompute_program_constant_int_count ", caps.getComputeProgramConstantIntCount(), "\n"));
        file.write(text("\tcompute_program_constant_bool_count ", caps.getComputeProgramConstantBoolCount(), "\n"));
        file.write(text("\tnum_vertex_texture_units ", caps.getNumVertexTextureUnits(), "\n"));
        
        file.write("\n}");
    }

    /** Writes a RenderSystemCapabilities object to a data stream */
    void writeScript(RenderSystemCapabilities caps, string name, string filename)
    {
        auto file = new FileHandleDataStream(filename, DataStream.AccessMode.WRITE);
        
        write(caps, name, file);
        
        file.close();
    }
    
    /** Writes a RenderSystemCapabilities object to a string */
    string writeString(RenderSystemCapabilities caps, string name)
    {
        ubyte[] buf;
        auto file = new MemoryDataStream(buf);
        
        write(caps, name, file);
        string str = file.getAsString();
        file.close();
        return str;
    }
    
    /** Parses a RenderSystemCapabilities script file passed as a stream.
     Adds it to RenderSystemCapabilitiesManager::_addRenderSystemCapabilities
     */
    void parseScript(DataStream stream)
    {
        // reset parsing data to NULL
        mCurrentLineNumber = 0;
        mCurrentLine = null;
        //mCurrentStream.setNull();
        mCurrentCapabilities = null;
        
        mCurrentStream = stream;
        
        // parser operating data
        string line;
        ParseAction parseAction = ParseAction.PARSE_HEADER;
        string[] tokens;
        bool parsedAtLeastOneRSC = false;
        
        // collect capabilities lines (i.e. everything that is not header, "{", "}",
        // comment or empty line) for further processing
        CapabilitiesLinesList capabilitiesLines;
        
        // for reading data
        char[/*OGRE_STREAM_TEMP_SIZE*/ 128] tmpBuf;
        
        
        // TODO: build a smarter tokenizer so that "{" and "}"
        // don't need separate lines
        while (!stream.eof())
        {
            //stream.readLine(tmpBuf, OGRE_STREAM_TEMP_SIZE-1);
            line = stream.getLine();
            //StringUtil::trim(line);
            
            // keep track of parse position
            mCurrentLine = line;
            mCurrentLineNumber++;
            
            tokens = StringConverter.parseString(line);
            
            // skip empty and comment lines
            // TODO: handle end of line comments
            if (tokens[0] == "" || tokens[0][0..2] == "//")
                continue;
            
            final switch (parseAction)
            {
                // header line must look like this:
                // render_system_capabilities "Vendor Card Name Version xx.xxx"
                
                case ParseAction.PARSE_HEADER:
                    
                    if(tokens[0] != "render_system_capabilities")
                    {
                        logParseError("The first keyword must be render_system_capabilities. RenderSystemCapabilities NOT created!");
                        return;
                    }
                    else
                    {
                        // the rest of the tokens are irrelevant, because everything between "..." is one name
                        string rscName = line[tokens[0].length .. $].strip();
                        //StringUtil::trim(rscName);
                        
                        // the second argument must be a "" delimited string
                        if (!StringUtil.match(rscName, "\"*\""))
                        {
                            logParseError("The argument to render_system_capabilities must be a quote delimited (\"...\") string. RenderSystemCapabilities NOT created!");
                            return;
                        }
                        else
                        {
                            // we have a valid header
                            
                            // remove quotes
                            rscName = rscName[1..$-1];
                            
                            // create RSC
                            mCurrentCapabilities = new RenderSystemCapabilities();
                            // RSCManager is responsible for deleting mCurrentCapabilities
                            RenderSystemCapabilitiesManager.getSingleton()._addRenderSystemCapabilities(rscName, mCurrentCapabilities);
                            
                            LogManager.getSingleton().logMessage("Created RenderSystemCapabilities" ~ rscName);
                            
                            // do next action
                            parseAction = ParseAction.FIND_OPEN_BRACE;
                            parsedAtLeastOneRSC = true;
                        }
                    }
                    
                    break;
                    
                case ParseAction.FIND_OPEN_BRACE:
                    if (tokens[0] != "{" || tokens.length != 1)
                    {
                        logParseError("Expected '{' got: " ~ line ~ ". Continuing to next line.");
                    }
                    else
                    {
                        parseAction = ParseAction.COLLECT_LINES;
                    }
                    
                    break;
                    
                case ParseAction.COLLECT_LINES:
                    if (tokens[0] == "}")
                    {
                        // this render_system_capabilities section is over
                        // let's process the data and look for the next one
                        parseCapabilitiesLines(capabilitiesLines);
                        capabilitiesLines.clear();
                        parseAction = ParseAction.PARSE_HEADER;
                        
                    }
                    else
                        capabilitiesLines.insert(pair!(string, int)(line, mCurrentLineNumber)); //TODO Assoc array probably can be used.
                    break;
                    
            }
        }
        
        // Datastream is empty
        // if we are still looking for header, this means that we have either
        // finished reading one, or this is an empty file
        if(parseAction == ParseAction.PARSE_HEADER && parsedAtLeastOneRSC == false)
        {
            logParseError ("The file is empty");
        }
        if(parseAction == ParseAction.FIND_OPEN_BRACE)
            
        {
            logParseError ("Bad .rendercaps file. Were not able to find a '{'");
        }
        if(parseAction == ParseAction.COLLECT_LINES)
        {
            logParseError ("Bad .rendercaps file. Were not able to find a '}'");
        }
        
    }
    
protected:
    
    
    enum CapabilityKeywordType 
    {
        UNDEFINED_CAPABILITY_TYPE = 0,
        SET_STRING_METHOD,
        SET_INT_METHOD,
        SET_BOOL_METHOD,
        SET_REAL_METHOD,
        SET_CAPABILITY_ENUM_BOOL,
        ADD_SHADER_PROFILE_STRING
    }
    // determines what keyword is what type of capability. For example:
    // "automipmap" and "pbuffer" are both activated with setCapability (passing RSC_AUTOMIPMAP and RSC_PBUFFER respectivelly)
    // while "max_num_multi_render_targets" is an integer and has it's own method: setMaxMultiNumRenderTargets
    // we need to know these types to automatically parse each capability
    //typedef map<String, CapabilityKeywordType>::type KeywordTypeMap;
    alias CapabilityKeywordType[string] KeywordTypeMap;
    KeywordTypeMap mKeywordTypeMap;
    
    //typedef void (RenderSystemCapabilities::*SetStringMethod)(string);
    alias void function(string) SetStringMethod;
    alias void delegate(string) SetStringMethodD;
    // maps capability keywords to setCapability(string cap) style methods
    //typedef map<String, SetStringMethod>::type SetStringMethodDispatchTable;
    alias SetStringMethod[string] SetStringMethodDispatchTable;
    SetStringMethodDispatchTable mSetStringMethodDispatchTable;
    
    // CapabilityKeywordType.SET_INT_METHOD parsing tables
    //typedef void (RenderSystemCapabilities::*SetIntMethod)(ushort);
    alias void delegate(ushort) SetIntMethodD;
    alias void function(ushort) SetIntMethod;
    //typedef map<String, SetIntMethod>::type SetIntMethodDispatchTable;
    alias SetIntMethod[string] SetIntMethodDispatchTable;
    SetIntMethodDispatchTable mSetIntMethodDispatchTable;
    
    // CapabilityKeywordType.SET_BOOL_METHOD parsing tables
    //typedef void (RenderSystemCapabilities::*SetBoolMethod)(bool);
    alias void delegate(bool) SetBoolMethodD;
    alias void function(bool) SetBoolMethod;
    //typedef map<String, SetBoolMethod>::type SetBoolMethodDispatchTable;
    alias SetBoolMethod[string] SetBoolMethodDispatchTable;
    SetBoolMethodDispatchTable mSetBoolMethodDispatchTable;
    
    // CapabilityKeywordType.SET_REAL_METHOD parsing tables
    //typedef void (RenderSystemCapabilities::*SetRealMethod)(Real);
    alias void delegate(Real) SetRealMethodD;
    alias void function(Real) SetRealMethod;
    //typedef map<String, SetRealMethod>::type SetRealMethodDispatchTable;
    alias SetRealMethod[string] SetRealMethodDispatchTable;
    SetRealMethodDispatchTable mSetRealMethodDispatchTable;
    
    //typedef map<String, Capabilities>::type CapabilitiesMap;
    alias Capabilities[string] CapabilitiesMap;
    CapabilitiesMap mCapabilitiesMap;
    
    void addCapabilitiesMapping(string name, Capabilities cap)
    {
        mCapabilitiesMap[name] = cap;
    }
    
    
    // capabilities lines for parsing are collected along with their line numbers for debugging
    //typedef vector<std::pair<String, int> >::type CapabilitiesLinesList;
    alias pair!(string, int)[] CapabilitiesLinesList;
    // the set of states that the parser can be in
    enum ParseAction {PARSE_HEADER, FIND_OPEN_BRACE, COLLECT_LINES};
    
    int mCurrentLineNumber;
    string mCurrentLine;
    DataStream mCurrentStream;
    
    RenderSystemCapabilities mCurrentCapabilities;
    
    void addKeywordType(string keyword, CapabilityKeywordType type)
    {
        mKeywordTypeMap[keyword] = type;
    }
    
    CapabilityKeywordType getKeywordType(string keyword)
    {
        auto it = keyword in mKeywordTypeMap;
        if(it !is null)
            return *it;
        else
        {
            logParseError("Can't find the type for keyword: " ~ keyword);
            return CapabilityKeywordType.UNDEFINED_CAPABILITY_TYPE;
        }
    }
    
    void addSetStringMethod(string keyword, SetStringMethod method)
    {
        mSetStringMethodDispatchTable[keyword] = method;
    }
    
    void callSetStringMethod(string keyword, string val)
    {
        auto ptr = keyword in mSetStringMethodDispatchTable;
        if (ptr !is null)
        {
            SetStringMethod m = *ptr;
            //(mCurrentCapabilities.*m)(val);
            //Convert plain method to delegate and set mCurrentCapabilities as 'this'
            toDelegate!SetStringMethodD(mCurrentCapabilities, m)(val);
        }
        else
        {
            logParseError("undefined keyword: " ~ keyword);
        }
    }
    
    
    void addSetIntMethod(string keyword, SetIntMethod method)
    {
        mSetIntMethodDispatchTable[keyword] = method;
    }
    
    void callSetIntMethod(string keyword, ushort val)
    {
        auto ptr = keyword in mSetIntMethodDispatchTable;
        if (ptr !is null)
        {
            SetIntMethod m = *ptr;
            //(mCurrentCapabilities.*m)(val);
            toDelegate!SetIntMethodD(mCurrentCapabilities, m)(val);
        }
        else
        {
            logParseError("undefined keyword: " ~ keyword);
        }  
    }
    

    void addSetBoolMethod(string keyword, SetBoolMethod method)
    {
        mSetBoolMethodDispatchTable[keyword] = method;
    }
    
    void callSetBoolMethod(string keyword, bool val)
    {
        auto ptr = keyword in mSetBoolMethodDispatchTable;
        if (ptr !is null)
        {
            SetBoolMethod m = *ptr;
            //(mCurrentCapabilities.*m)(val);
            toDelegate!SetBoolMethodD(mCurrentCapabilities, m)(val);
        }
        else
        {
            logParseError("undefined keyword: " ~ keyword);
        }
    }
    
    
    void addSetRealMethod(string keyword, SetRealMethod method)
    {
        mSetRealMethodDispatchTable[keyword] = method;
    }
    
    void callSetRealMethod(string keyword, Real val)
    {
        auto ptr = keyword in mSetRealMethodDispatchTable;
        if (ptr !is null)
        {
            SetRealMethod m = *ptr;
            toDelegate!SetRealMethodD(mCurrentCapabilities, m)(val);
        }
        else
        {
            logParseError("undefined keyword: " ~ keyword);
        }
    }
    
    void addShaderProfile(string val)
    {
        mCurrentCapabilities.addShaderProfile(val);
    }
    
    void setCapabilityEnumBool(string name, bool val)
    {
        // check for errors
        if((name in mCapabilitiesMap) is null)
        {
            logParseError("Undefined capability: " ~ name);
            return;
        }
        // only set true capabilities, we can't unset false
        if(val)
        {
            Capabilities cap = mCapabilitiesMap[name];
            mCurrentCapabilities.setCapability(cap);
        }
    }

    //FIXME wrong-code, Making static because "this for <someFunc> needs to be type <Class> not type <AnotherClass>" :/
    static void initialiaseDispatchTables(RenderSystemCapabilitiesSerializer ser)
    {
        // set up driver version parsing
        ser.addKeywordType("driver_version", CapabilityKeywordType.SET_STRING_METHOD);
        // set up the setters for driver versions
        ser.addSetStringMethod("driver_version", &RenderSystemCapabilities.parseDriverVersionFromString);
        
        // set up device name parsing
        ser.addKeywordType("device_name", CapabilityKeywordType.SET_STRING_METHOD);
        // set up the setters for device names
        ser.addSetStringMethod("device_name", &RenderSystemCapabilities.setDeviceName);
        
        // set up render system name parsing
        ser.addKeywordType("render_system_name", CapabilityKeywordType.SET_STRING_METHOD);
        // set up the setters 
        ser.addSetStringMethod("render_system_name", &RenderSystemCapabilities.setRenderSystemName);
        
        // set up vendor parsing
        ser.addKeywordType("vendor", CapabilityKeywordType.SET_STRING_METHOD);
        // set up the setters for driver versions
        ser.addSetStringMethod("vendor", &RenderSystemCapabilities.parseVendorFromString);
        
        // initialize int types
        ser.addKeywordType("num_world_matrices", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("num_texture_units", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("stencil_buffer_bit_depth", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("num_vertex_blend_matrices", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("num_multi_render_targets", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("vertex_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("vertex_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("vertex_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("fragment_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("fragment_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("fragment_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("geometry_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("geometry_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("geometry_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_hull_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_hull_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_hull_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_domain_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_domain_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("tesselation_domain_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("compute_program_constant_float_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("compute_program_constant_int_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("compute_program_constant_bool_count", CapabilityKeywordType.SET_INT_METHOD);
        ser.addKeywordType("num_vertex_texture_units", CapabilityKeywordType.SET_INT_METHOD);
        
        // initialize int setters
        ser.addSetIntMethod("num_world_matrices", &RenderSystemCapabilities.setNumWorldMatrices);
        ser.addSetIntMethod("num_texture_units", &RenderSystemCapabilities.setNumTextureUnits);
        ser.addSetIntMethod("stencil_buffer_bit_depth", &RenderSystemCapabilities.setStencilBufferBitDepth);
        ser.addSetIntMethod("num_vertex_blend_matrices", &RenderSystemCapabilities.setNumVertexBlendMatrices);
        ser.addSetIntMethod("num_multi_render_targets", &RenderSystemCapabilities.setNumMultiRenderTargets);
        ser.addSetIntMethod("vertex_program_constant_float_count", &RenderSystemCapabilities.setVertexProgramConstantFloatCount);
        ser.addSetIntMethod("vertex_program_constant_int_count", &RenderSystemCapabilities.setVertexProgramConstantIntCount);
        ser.addSetIntMethod("vertex_program_constant_bool_count", &RenderSystemCapabilities.setVertexProgramConstantBoolCount);
        ser.addSetIntMethod("fragment_program_constant_float_count", &RenderSystemCapabilities.setFragmentProgramConstantFloatCount);
        ser.addSetIntMethod("fragment_program_constant_int_count", &RenderSystemCapabilities.setFragmentProgramConstantIntCount);
        ser.addSetIntMethod("fragment_program_constant_bool_count", &RenderSystemCapabilities.setFragmentProgramConstantBoolCount);
        ser.addSetIntMethod("geometry_program_constant_float_count", &RenderSystemCapabilities.setGeometryProgramConstantFloatCount);
        ser.addSetIntMethod("geometry_program_constant_int_count", &RenderSystemCapabilities.setGeometryProgramConstantIntCount);
        ser.addSetIntMethod("geometry_program_constant_bool_count", &RenderSystemCapabilities.setGeometryProgramConstantBoolCount);
        ser.addSetIntMethod("tesselation_hull_program_constant_float_count", &RenderSystemCapabilities.setTesselationHullProgramConstantFloatCount);
        ser.addSetIntMethod("tesselation_hull_program_constant_int_count", &RenderSystemCapabilities.setTesselationHullProgramConstantIntCount);
        ser.addSetIntMethod("tesselation_hull_program_constant_bool_count", &RenderSystemCapabilities.setTesselationHullProgramConstantBoolCount);
        ser.addSetIntMethod("tesselation_domain_program_constant_float_count", &RenderSystemCapabilities.setTesselationDomainProgramConstantFloatCount);
        ser.addSetIntMethod("tesselation_domain_program_constant_int_count", &RenderSystemCapabilities.setTesselationDomainProgramConstantIntCount);
        ser.addSetIntMethod("tesselation_domain_program_constant_bool_count", &RenderSystemCapabilities.setTesselationDomainProgramConstantBoolCount);
        ser.addSetIntMethod("compute_program_constant_float_count", &RenderSystemCapabilities.setComputeProgramConstantFloatCount);
        ser.addSetIntMethod("compute_program_constant_int_count", &RenderSystemCapabilities.setComputeProgramConstantIntCount);
        ser.addSetIntMethod("compute_program_constant_bool_count", &RenderSystemCapabilities.setComputeProgramConstantBoolCount);
        ser.addSetIntMethod("num_vertex_texture_units", &RenderSystemCapabilities.setNumVertexTextureUnits);
        
        // initialize bool types
        ser.addKeywordType("non_pow2_textures_limited", CapabilityKeywordType.SET_BOOL_METHOD);
        ser.addKeywordType("vertex_texture_units_shared", CapabilityKeywordType.SET_BOOL_METHOD);
        
        // initialize bool setters
        ser.addSetBoolMethod("non_pow2_textures_limited", &RenderSystemCapabilities.setNonPOW2TexturesLimited);
        ser.addSetBoolMethod("vertex_texture_units_shared", &RenderSystemCapabilities.setVertexTextureUnitsShared);
        
        // initialize Real types
        ser.addKeywordType("max_point_size", CapabilityKeywordType.SET_REAL_METHOD);
        
        // initialize Real setters
        ser.addSetRealMethod("max_point_size", &RenderSystemCapabilities.setMaxPointSize);
        
        // there is no dispatch table for shader profiles, just the type
        ser.addKeywordType("shader_profile", CapabilityKeywordType.ADD_SHADER_PROFILE_STRING);
        
        // set up RSC_XXX style capabilities
        ser.addKeywordType("fixed_function", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("automipmap", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("blending", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("anisotropy", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("dot3", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("cubemapping", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("hwstencil", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("vbo", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("vertex_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("geometry_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("fragment_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("tesselation_hull_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("tesselation_domain_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("compute_program", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("scissor_test", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("two_sided_stencil", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("stencil_wrap", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("hwocclusion", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("user_clip_planes", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("vertex_format_ubyte4", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("infinite_far_plane", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("hwrender_to_texture", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_float", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("non_power_of_2_textures", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_1d", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_3d", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("point_sprites", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("point_extended_parameters", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("vertex_texture_fetch", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("mipmap_lod_bias", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("atomic_counters", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression_dxt", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression_vtc", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression_pvrtc", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression_bc4_bc5", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("texture_compression_bc6h_bc7", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("gl1_5_novbo", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("fbo", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("fbo_arb", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("fbo_ati", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("pbuffer", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("gl1_5_nohwocclusion", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("perstageconstant", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("vao", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        ser.addKeywordType("separate_shader_objects", CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL);
        
        ser.addCapabilitiesMapping("fixed_function", Capabilities.RSC_FIXED_FUNCTION);
        ser.addCapabilitiesMapping("automipmap", Capabilities.RSC_AUTOMIPMAP);
        ser.addCapabilitiesMapping("blending", Capabilities.RSC_BLENDING);
        ser.addCapabilitiesMapping("anisotropy", Capabilities.RSC_ANISOTROPY);
        ser.addCapabilitiesMapping("dot3", Capabilities.RSC_DOT3);
        ser.addCapabilitiesMapping("cubemapping", Capabilities.RSC_CUBEMAPPING);
        ser.addCapabilitiesMapping("hwstencil", Capabilities.RSC_HWSTENCIL);
        ser.addCapabilitiesMapping("vbo", Capabilities.RSC_VBO);
        ser.addCapabilitiesMapping("vertex_program", Capabilities.RSC_VERTEX_PROGRAM);
        ser.addCapabilitiesMapping("geometry_program", Capabilities.RSC_GEOMETRY_PROGRAM);
        ser.addCapabilitiesMapping("fragment_program", Capabilities.RSC_FRAGMENT_PROGRAM);
        ser.addCapabilitiesMapping("tesselation_hull_program", Capabilities.RSC_TESSELATION_HULL_PROGRAM);
        ser.addCapabilitiesMapping("tesselation_domain_program", Capabilities.RSC_TESSELATION_DOMAIN_PROGRAM);
        ser.addCapabilitiesMapping("compute_program", Capabilities.RSC_COMPUTE_PROGRAM);
        ser.addCapabilitiesMapping("scissor_test", Capabilities.RSC_SCISSOR_TEST);
        ser.addCapabilitiesMapping("two_sided_stencil", Capabilities.RSC_TWO_SIDED_STENCIL);
        ser.addCapabilitiesMapping("stencil_wrap", Capabilities.RSC_STENCIL_WRAP);
        ser.addCapabilitiesMapping("hwocclusion", Capabilities.RSC_HWOCCLUSION);
        ser.addCapabilitiesMapping("user_clip_planes", Capabilities.RSC_USER_CLIP_PLANES);
        ser.addCapabilitiesMapping("vertex_format_ubyte4", Capabilities.RSC_VERTEX_FORMAT_UBYTE4);
        ser.addCapabilitiesMapping("infinite_far_plane", Capabilities.RSC_INFINITE_FAR_PLANE);
        ser.addCapabilitiesMapping("hwrender_to_texture", Capabilities.RSC_HWRENDER_TO_TEXTURE);
        ser.addCapabilitiesMapping("texture_float", Capabilities.RSC_TEXTURE_FLOAT);
        ser.addCapabilitiesMapping("non_power_of_2_textures", Capabilities.RSC_NON_POWER_OF_2_TEXTURES);
        ser.addCapabilitiesMapping("texture_3d", Capabilities.RSC_TEXTURE_3D);
        ser.addCapabilitiesMapping("texture_1d", Capabilities.RSC_TEXTURE_1D);
        ser.addCapabilitiesMapping("point_sprites", Capabilities.RSC_POINT_SPRITES);
        ser.addCapabilitiesMapping("point_extended_parameters", Capabilities.RSC_POINT_EXTENDED_PARAMETERS);
        ser.addCapabilitiesMapping("vertex_texture_fetch", Capabilities.RSC_VERTEX_TEXTURE_FETCH);
        ser.addCapabilitiesMapping("mipmap_lod_bias", Capabilities.RSC_MIPMAP_LOD_BIAS);
        ser.addCapabilitiesMapping("atomic_counters", Capabilities.RSC_ATOMIC_COUNTERS);
        ser.addCapabilitiesMapping("texture_compression", Capabilities.RSC_TEXTURE_COMPRESSION);
        ser.addCapabilitiesMapping("texture_compression_dxt", Capabilities.RSC_TEXTURE_COMPRESSION_DXT);
        ser.addCapabilitiesMapping("texture_compression_vtc", Capabilities.RSC_TEXTURE_COMPRESSION_VTC);
        ser.addCapabilitiesMapping("texture_compression_pvrtc", Capabilities.RSC_TEXTURE_COMPRESSION_PVRTC);
        ser.addCapabilitiesMapping("texture_compression_bc4_bc5", Capabilities.RSC_TEXTURE_COMPRESSION_BC4_BC5);
        ser.addCapabilitiesMapping("texture_compression_bc6h_bc7", Capabilities.RSC_TEXTURE_COMPRESSION_BC6H_BC7);
        ser.addCapabilitiesMapping("hwrender_to_vertex_buffer", Capabilities.RSC_HWRENDER_TO_VERTEX_BUFFER);
        ser.addCapabilitiesMapping("gl1_5_novbo", Capabilities.RSC_GL1_5_NOVBO);
        ser.addCapabilitiesMapping("fbo", Capabilities.RSC_FBO);
        ser.addCapabilitiesMapping("fbo_arb", Capabilities.RSC_FBO_ARB);
        ser.addCapabilitiesMapping("fbo_ati", Capabilities.RSC_FBO_ATI);
        ser.addCapabilitiesMapping("pbuffer", Capabilities.RSC_PBUFFER);
        ser.addCapabilitiesMapping("gl1_5_nohwocclusion", Capabilities.RSC_GL1_5_NOHWOCCLUSION);
        ser.addCapabilitiesMapping("perstageconstant", Capabilities.RSC_PERSTAGECONSTANT);
        ser.addCapabilitiesMapping("vao", Capabilities.RSC_VAO);
        ser.addCapabilitiesMapping("separate_shader_objects", Capabilities.RSC_SEPARATE_SHADER_OBJECTS);
        
    }
    
    void parseCapabilitiesLines(ref CapabilitiesLinesList linesList)
    {
        string[] tokens;
        
        foreach (it; linesList)
        {
            // restore the current line information for debugging
            mCurrentLine = it.first;
            mCurrentLineNumber = it.second;
            
            tokens = StringConverter.parseString(it.first);
            // check for incomplete lines
            if(tokens.length < 2)
            {
                logParseError("No parameters given for the capability keyword");
                continue;
            }
            
            // the first token must the the keyword identifying the capability
            // the remaining tokens are the parameters
            string keyword = tokens[0];
            string everythingElse = "";
            foreach(i; tokens[1..$-1]) // $ exclusive and slice
            {
                everythingElse = everythingElse ~ i ~ " ";
            }
            everythingElse = everythingElse ~ tokens[$ - 1]; // $ inclusive and array
            
            CapabilityKeywordType keywordType = getKeywordType(keyword);
            
            final switch(keywordType)
            {
                case CapabilityKeywordType.UNDEFINED_CAPABILITY_TYPE:
                    logParseError("Unknown capability keyword: " ~ keyword);
                    break;
                case CapabilityKeywordType.SET_STRING_METHOD:
                    callSetStringMethod(keyword, everythingElse);
                    break;
                case CapabilityKeywordType.SET_INT_METHOD:
                {
                    ushort integer = to!ushort(tokens[1]);
                    callSetIntMethod(keyword, integer);
                    break;
                }
                case CapabilityKeywordType.SET_BOOL_METHOD:
                {
                    bool b = to!bool(tokens[1]);
                    callSetBoolMethod(keyword, b);
                    break;
                }
                case CapabilityKeywordType.SET_REAL_METHOD:
                {
                    Real r = to!Real(tokens[1]);
                    callSetRealMethod(keyword, r);
                    break;
                }
                case CapabilityKeywordType.ADD_SHADER_PROFILE_STRING:
                {
                    addShaderProfile(tokens[1]);
                    break;
                }
                case CapabilityKeywordType.SET_CAPABILITY_ENUM_BOOL:
                {
                    bool b = to!bool(tokens[1]);
                    setCapabilityEnumBool(tokens[0], b);
                    break;
                }
            }
        }
    }
    
    void logParseError(string error)
    {
        // log the line with error in it if the current line is available
        if (mCurrentLine !is null && (mCurrentStream !is null))
        {
            LogManager.getSingleton().logMessage(
                std.conv.text("Error in .rendercaps ", mCurrentStream.getName(), ":", mCurrentLineNumber, " : ", error));
        }
        else if (mCurrentStream !is null)
        {
            LogManager.getSingleton().logMessage(
                std.conv.text("Error in .rendercaps ", mCurrentStream.getName(), " : ", error));
        }
    }
    
}
/** @} */
/** @} */
