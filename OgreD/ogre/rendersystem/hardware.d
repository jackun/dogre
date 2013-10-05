module ogre.rendersystem.hardware;
/// Split stuff out from ogre.rendersystem for less LOC per module

private
{
    //import std.container;
    import core.sync.mutex;
    import std.conv: to;
    import std.array;
}

import ogre.compat;
import ogre.singleton;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.exception;
import ogre.general.generals;
import ogre.general.root;
import ogre.general.common;
import ogre.rendersystem.vertex;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.rendertexture;
import ogre.general.log;
public import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup RenderSystem
 *  @{
 */

/**
 * This is a abstract class that that provides the interface for the query class for 
 * hardware occlusion.
 *
 * @author Lee Sandberg
 * Updated on 13/8/2005 by Tuan Kuranes email: tuan.kuranes@free.fr
 */
//TODO Class or interface?
//interface 
class HardwareOcclusionQuery
{
    /**
     * Starts the hardware occlusion query
     * @remarks    Simple usage: Create one or more OcclusionQuery object one per outstanding query or one per tested object 
     *             OcclusionQuery* mOcclusionQuery;
     *             createOcclusionQuery( &mOcclusionQuery );
     *             In the rendering loop:
     *             Draw all occluders
     *             mOcclusionQuery.startOcclusionQuery();
     *             Draw the polygons to be tested
     *             mOcclusionQuery.endOcclusionQuery();
     *
     *             Results must be pulled using:
     *             UINT    mNumberOfPixelsVisable;
     *             pullOcclusionQuery( &mNumberOfPixelsVisable );
     *         
     */
    abstract void beginOcclusionQuery();
    
    /**
     * Ends the hardware occlusion test
     */
    abstract void endOcclusionQuery();
    
    /**
     * Pulls the hardware occlusion query.
     * @note Waits until the query result is available; use isStillOutstanding
     *     if just want to test if the result is available.
     * @retval NumOfFragments will get the resulting number of fragments.
     * @return True if success or false if not.
     */
    abstract bool pullOcclusionQuery(uint* NumOfFragments);
    
    /**
     * Let's you get the last pixel count with out doing the hardware occlusion test
     * @return The last fragment count from the last test.
     * Remarks This function won't give you new values, just the old value.
     */
    uint getLastQuerysPixelcount(){ return mPixelCount; }
    
    /**
     * Lets you know when query is done, or still be processed by the Hardware
     * @return true if query isn't finished.
     */
    abstract bool isStillOutstanding(); 
    
    
    //----------------------------------------------------------------------
    // protected members
    //--
protected :
    /// Numbers of visible pixels determined by last query
    uint mPixelCount = 0;
    /// Has the query returned a result yet?
    bool         mIsQueryResultStillOutstanding = false;
}

/** Abstract class defining common features of hardware buffers.
 @remarks
 A 'hardware buffer' is any area of memory held outside of core system ram,
 and in our case ref ers mostly to video ram, although in theory this class
 could be used with other memory areas such as sound card memory, custom
 coprocessor memory etc.
 @par
 This reflects the fact that memory held outside of main system RAM must
 be interacted with in a more formal fashion in order to promote
 cooperative and optimal usage of the buffers between the various
 processing units which manipulate them.
 @par
 This abstract class defines the core interface which is common to all
 buffers, whether it be vertex buffers, index buffers, texture memory
 or framebuffer memory etc.
 @par
 Buffers have the ability to be 'shadowed' in system memory, this is because
 the kinds of access allowed on hardware buffers is not always as flexible as
 that allowed for areas of system memory - for example it is often either
 impossible, or extremely undesirable from a performance standpoint to read from
 a hardware buffer; when writing to hardware buffers, you should also write every
 byte and do it sequentially. In situations where this is too restrictive,
 it is possible to create a hardware, write-only buffer (the most efficient kind)
 and to back it with a system memory 'shadow' copy which can be read and updated arbitrarily.
 Ogre handles synchronising this buffer with the real hardware buffer (which should still be
 created with the Usage.HBU_DYNAMIC flag if you intend to update it very frequently). Whilst this
 approach does have it's own costs, such as increased memory overhead, these costs can
 often be outweighed by the performance benefits of using a more hardware efficient buffer.
 You should look for the 'useShadowBuffer' parameter on the creation methods used to create
 the buffer of the type you require (see HardwareBufferManager) to enable this feature.
 */
class HardwareBuffer// : public BufferAlloc
{
    
public:
    /// Enums describing buffer usage; not mutually exclusive
    enum Usage
    {
        /** Static buffer which the application rarely modifies once created. Modifying
         the contents of this buffer will involve a performance hit.
         */
        HBU_STATIC = 1,
        /** Indicates the application would like to modify this buffer with the CPU
         fairly often.
         Buffers created with this flag will typically end up in AGP memory rather
         than video memory.
         */
        HBU_DYNAMIC = 2,
        /** Indicates the application will never read the contents of the buffer back,
         it will only ever write data. Locking a buffer with this flag will ALWAYS
         return a pointer to new, blank memory rather than the memory associated
         with the contents of the buffer; this avoids DMA stalls because you can
         write to a new memory area while the previous one is being used.
         */
        HBU_WRITE_ONLY = 4,
        /** Indicates that the application will be ref illing the contents
         of the buffer regularly (not just updating, but generating the
         contents from scratch), and Therefore does not mind if the contents
         of the buffer are lost somehow and need to be recreated. This
         allows and additional level of optimisation on the buffer.
         This option only really makes sense when combined with
         Usage.HBU_DYNAMIC_WRITE_ONLY.
         */
        HBU_DISCARDABLE = 8,
        /// Combination of Usage.HBU_STATIC and Usage.HBU_WRITE_ONLY
        HBU_STATIC_WRITE_ONLY = 5,
        /** Combination of Usage.HBU_DYNAMIC and Usage.HBU_WRITE_ONLY. If you use
         this, strongly consider using Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE
         instead if you update the entire contents of the buffer very
         regularly.
         */
        HBU_DYNAMIC_WRITE_ONLY = 6,
        /// Combination of Usage.HBU_DYNAMIC, Usage.HBU_WRITE_ONLY and Usage.HBU_DISCARDABLE
        HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE = 14
        
        
    }
    /// Locking options
    enum LockOptions
    {
        /** Normal mode, ie allows read/write and contents are preserved. */
        HBL_NORMAL,
        /** Discards the <em>entire</em> buffer while locking; this allows optimisation to be
         performed because synchronisation issues are relaxed. Only allowed on buffers
         created with the Usage.HBU_DYNAMIC flag.
         */
        HBL_DISCARD,
        /** Lock the buffer for reading only. Not allowed in buffers which are created with Usage.HBU_WRITE_ONLY.
         Mandatory on static buffers, i.e. those created without the Usage.HBU_DYNAMIC flag.
         */
        HBL_READ_ONLY,
        /** As LockOptions.HBL_NORMAL, except the application guarantees not to overwrite any
         region of the buffer which has already been used in this frame, can allow
         some optimisation on some APIs. */
        HBL_NO_OVERWRITE,
        /** Lock the buffer for writing only.*/
        HBL_WRITE_ONLY
        
    }
protected:
    size_t mSizeInBytes;
    Usage mUsage;
    bool mIsLocked;
    size_t mLockStart;
    size_t mLockSize;
    bool mSystemMemory;
    bool mUseShadowBuffer;
    HardwareBuffer mShadowBuffer;
    bool mShadowUpdated;
    bool mSuppressHardwareUpdate;
    
    /// Internal implementation of lock()
    abstract void* lockImpl(size_t offset, size_t length, LockOptions options);
    /// Internal implementation of unlock()
    abstract void unlockImpl();
    
public:
    /// Constructor, to be called by HardwareBufferManager only
    this(Usage usage, bool systemMemory, bool useShadowBuffer)
    {
        mUsage = usage;
        mIsLocked = false;
        mSystemMemory = systemMemory;
        mUseShadowBuffer = useShadowBuffer;
        mShadowBuffer = null;
        mShadowUpdated = false;
        mSuppressHardwareUpdate = false;
        // If use shadow buffer, upgrade to WRITE_ONLY on hardware side
        if (useShadowBuffer && usage == Usage.HBU_DYNAMIC)
        {
            mUsage = Usage.HBU_DYNAMIC_WRITE_ONLY;
        }
        else if (useShadowBuffer && usage == Usage.HBU_STATIC)
        {
            mUsage = Usage.HBU_STATIC_WRITE_ONLY;
        }
    }
    ~this() {}
    /** Lock the buffer for (potentially) reading / writing.
     @param offset The byte offset from the start of the buffer to lock
     @param length The size of the area to lock, in bytes
     @param options Locking options
     @return Pointer to the locked memory
     */
    void* lock(size_t offset, size_t length, LockOptions options)
    {
        assert(!isLocked(), "Cannot lock this buffer, it is already locked!");
        
        void* ret = null;
        if ((length + offset) > mSizeInBytes)
        {
            throw new InvalidParamsError(
                "Lock request out of bounds.",
                "HardwareBuffer.lock");
        }
        else if (mUseShadowBuffer)
        {
            if (options != LockOptions.HBL_READ_ONLY)
            {
                // we have to assume a read / write lock so we use the shadow buffer
                // and tag for sync on unlock()
                mShadowUpdated = true;
            }
            
            ret = mShadowBuffer.lock(offset, length, options);
        }
        else
        {
            // Lock the real buffer if there is no shadow buffer
            ret = lockImpl(offset, length, options);
            mIsLocked = true;
        }
        mLockStart = offset;
        mLockSize = length;
        return ret;
    }
    
    /** Lock the entire buffer for (potentially) reading / writing.
     @param options Locking options
     @return Pointer to the locked memory
     */
    void* lock(LockOptions options)
    {
        return this.lock(0, mSizeInBytes, options);
    }
    /** Releases the lock on this buffer.
     @remarks
     Locking and unlocking a buffer can, in some rare circumstances such as
     switching video modes whilst the buffer is locked, corrupt the
     contents of a buffer. This is pretty rare, but if it occurs,
     this method will throw an exception, meaning you
     must re-upload the data.
     @par
     Note that using the 'read' and 'write' forms of updating the buffer does not
     suffer from this problem, so if you want to be 100% sure your
     data will not be lost, use the 'read' and 'write' forms instead.
     */
    void unlock()
    {
        assert(isLocked(), "Cannot unlock this buffer, it is not locked!");
        
        // If we used the shadow buffer this time...
        if (mUseShadowBuffer && mShadowBuffer.isLocked())
        {
            mShadowBuffer.unlock();
            // Potentially update the 'real' buffer from the shadow buffer
            _updateFromShadow();
        }
        else
        {
            // Otherwise, unlock the real one
            unlockImpl();
            mIsLocked = false;
        }
        
    }
    
    /** Reads data from the buffer and places it in the memory pointed to by pDest.
     @param offset The byte offset from the start of the buffer to read
     @param length The size of the area to read, in bytes
     @param pDest The area of memory in which to place the data, must be large enough to
     accommodate the data!
     */
    abstract void readData(size_t offset, size_t length, void* pDest);
    /*{
     onNotImplementedError();
     }*/
    /** Writes data to the buffer from an area of system memory; note that you must
     ensure that your buffer is big enough.
     @param offset The byte offset from the start of the buffer to start writing
     @param length The size of the data to write to, in bytes
     @param pSource The source of the data to be written
     @param discardWholeBuffer If true, this allows the driver to discard the entire buffer when writing,
     such that DMA stalls can be avoided; use if you can.
     */
    abstract void writeData(size_t offset, size_t length,void* pSource,
                            bool discardWholeBuffer = false);
    /*{
     onNotImplementedError();
     }*/
    
    /** Copy data from another buffer into this one.
     @remarks
     Note that the source buffer must not be created with the
     usage Usage.HBU_WRITE_ONLY otherwise this will fail.
     @param srcBuffer The buffer from which to read the copied data
     @param srcOffset Offset in the source buffer at which to start reading
     @param dstOffset Offset in the destination buffer to start writing
     @param length Length of the data to copy, in bytes.
     @param discardWholeBuffer If true, will discard the entire contents of this buffer before copying
     */
    void copyData(HardwareBuffer srcBuffer, size_t srcOffset,
                  size_t dstOffset, size_t length, bool discardWholeBuffer = false)
    {
        void *srcData = srcBuffer.lock(srcOffset, length, LockOptions.HBL_READ_ONLY);
        this.writeData(dstOffset, length, srcData, discardWholeBuffer);
        srcBuffer.unlock();
    }
    
    /** Copy all data from another buffer into this one.
     @remarks
     Normally these buffers should be of identical size, but if they're
     not, the routine will use the smallest of the two sizes.
     */
    void copyData(ref HardwareBuffer srcBuffer)
    {
        size_t sz = std.algorithm.min(getSizeInBytes(), srcBuffer.getSizeInBytes());
        copyData(srcBuffer, 0, 0, sz, true);
    }
    
    /// Updates the real buffer from the shadow buffer, if required
    void _updateFromShadow()
    {
        if (mUseShadowBuffer && mShadowUpdated && !mSuppressHardwareUpdate)
        {
            // Do this manually to avoid locking problems
            void *srcData = mShadowBuffer.lockImpl(
                mLockStart, mLockSize, LockOptions.HBL_READ_ONLY);
            // Lock with discard if the whole buffer was locked, otherwise normal
            LockOptions lockOpt;
            if (mLockStart == 0 && mLockSize == mSizeInBytes)
                lockOpt = LockOptions.HBL_DISCARD;
            else
                lockOpt = LockOptions.HBL_NORMAL;
            
            void *destData = this.lockImpl(
                mLockStart, mLockSize, lockOpt);
            // Copy shadow to real
            memcpy(destData, srcData, mLockSize);
            this.unlockImpl();
            mShadowBuffer.unlockImpl();
            mShadowUpdated = false;
        }
    }
    
    /// Returns the size of this buffer in bytes
    size_t getSizeInBytes() const { return mSizeInBytes; }
    /// Returns the Usage flags with which this buffer was created
    Usage getUsage() const { return mUsage; }
    /// Returns whether this buffer is held in system memory
    bool isSystemMemory() const { return mSystemMemory; }
    /// Returns whether this buffer has a system memory shadow for quicker reading
    bool hasShadowBuffer() const { return mUseShadowBuffer; }
    /// Returns whether or not this buffer is currently locked.
    bool isLocked(){
        return mIsLocked || (mUseShadowBuffer && mShadowBuffer.isLocked());
    }
    /// Pass true to suppress hardware upload of shadow buffer changes
    void suppressHardwareUpdate(bool suppress) {
        mSuppressHardwareUpdate = suppress;
        if (!suppress)
            _updateFromShadow();
    }
}

/** Abstract interface representing a 'licensee' of a hardware buffer copy.
 @remarks
 Often it's useful to have temporary buffers which are used for working
 but are not necessarily needed permanently. However, creating and
 destroying buffers is expensive, so we need a way to share these
 working areas, especially those based on existing fixed buffers.
 This class represents a licensee of one of those temporary buffers,
 and must be implemented by any user of a temporary buffer if they
 wish to be notified when the license is expired.
 */
//class HardwareBufferLicensee
interface HardwareBufferLicensee
{
public:
    //~this() { }
    /** This method is called when the buffer license is expired and is about
     to be returned to the shared pool.
     */
    void licenseExpired(HardwareBuffer buffer);
}

/** Structure for recording the use of temporary blend buffers. */
class TempBlendedBufferInfo : HardwareBufferLicensee //, public BufferAlloc
{
private:
    // Pre-blended
    SharedPtr!HardwareVertexBuffer srcPositionBuffer;
    SharedPtr!HardwareVertexBuffer srcNormalBuffer;
    // Post-blended
    SharedPtr!HardwareVertexBuffer destPositionBuffer;
    SharedPtr!HardwareVertexBuffer destNormalBuffer;
    /// Both positions and normals are contained in the same buffer.
    bool posNormalShareBuffer;
    ushort posBindIndex;
    ushort normBindIndex;
    bool bindPositions;
    bool bindNormals;
    
public:
    ~this()
    {
        // check that temp buffers have been released
        if (!destPositionBuffer.isNull())
            destPositionBuffer.get().getManager().releaseVertexBufferCopy(destPositionBuffer);
        if (!destNormalBuffer.isNull())
            destNormalBuffer.get().getManager().releaseVertexBufferCopy(destNormalBuffer);
    }
    /// Utility method, extract info from the given VertexData.
    void extractFrom(VertexData sourceData)
    {
        // Release old buffer copies first
        if (!destPositionBuffer.isNull())
        {
            destPositionBuffer.get().getManager().releaseVertexBufferCopy(destPositionBuffer);
            assert(destPositionBuffer.isNull());
        }
        if (!destNormalBuffer.isNull())
        {
            destNormalBuffer.get().getManager().releaseVertexBufferCopy(destNormalBuffer);
            assert(destNormalBuffer.isNull());
        }
        
        VertexDeclaration decl = sourceData.vertexDeclaration;
        VertexBufferBinding bind = sourceData.vertexBufferBinding;
        VertexElement posElem = decl.findElementBySemantic(VertexElementSemantic.VES_POSITION);
        VertexElement normElem = decl.findElementBySemantic(VertexElementSemantic.VES_NORMAL);
        
        assert(posElem , "Positions are required");
        
        posBindIndex = posElem.getSource();
        srcPositionBuffer = bind.getBuffer(posBindIndex);
        
        if (!normElem)
        {
            posNormalShareBuffer = false;
            srcNormalBuffer.setNull();
        }
        else
        {
            normBindIndex = normElem.getSource();
            if (normBindIndex == posBindIndex)
            {
                posNormalShareBuffer = true;
                srcNormalBuffer.setNull();
            }
            else
            {
                posNormalShareBuffer = false;
                srcNormalBuffer = bind.getBuffer(normBindIndex);
            }
        }
    }
    /// Utility method, checks out temporary copies of src into dest.
    void checkoutTempCopies(bool positions = true, bool normals = true)
    {
        bindPositions = positions;
        bindNormals = normals;
        
        if (positions && destPositionBuffer.isNull())
        {
            destPositionBuffer = srcPositionBuffer.get().getManager().
                allocateVertexBufferCopy(srcPositionBuffer,
                                         HardwareBufferManagerBase.BufferLicenseType.BLT_AUTOMATIC_RELEASE, this);
        }
        if (normals && !posNormalShareBuffer && !srcNormalBuffer.isNull() && destNormalBuffer.isNull())
        {
            destNormalBuffer = srcNormalBuffer.get().getManager().
                allocateVertexBufferCopy(srcNormalBuffer,
                                         HardwareBufferManagerBase.BufferLicenseType.BLT_AUTOMATIC_RELEASE, this);
        }
    }
    /// Utility method, binds dest copies into a given VertexData struct.
    void bindTempCopies(ref VertexData targetData, bool suppressHardwareUpload)
    {
        this.destPositionBuffer.get().suppressHardwareUpdate(suppressHardwareUpload);
        targetData.vertexBufferBinding.setBinding(
            this.posBindIndex, this.destPositionBuffer);
        if (bindNormals && !posNormalShareBuffer && !destNormalBuffer.isNull())
        {
            this.destNormalBuffer.get().suppressHardwareUpdate(suppressHardwareUpload);
            targetData.vertexBufferBinding.setBinding(
                this.normBindIndex, this.destNormalBuffer);
        }
    }
    /** Overridden member from HardwareBufferLicensee. */
    void licenseExpired(HardwareBuffer buffer)
    {
        assert(buffer == destPositionBuffer.get()
               || buffer == destNormalBuffer.get());
        
        if (buffer == destPositionBuffer.get())
            destPositionBuffer.setNull();
        if (buffer == destNormalBuffer.get())
            destNormalBuffer.setNull();
    }
    /** Detect currently have buffer copies checked out and touch it. */
    bool buffersCheckedOut(bool positions = true, bool normals = true)
    {
        if (positions || (normals && posNormalShareBuffer))
        {
            if (destPositionBuffer.isNull())
                return false;
            
            destPositionBuffer.get().getManager().touchVertexBufferCopy(destPositionBuffer);
        }
        
        if (normals && !posNormalShareBuffer)
        {
            if (destNormalBuffer.isNull())
                return false;
            
            destNormalBuffer.get().getManager().touchVertexBufferCopy(destNormalBuffer);
        }
        
        return true;
    }
}


/** Base definition of a hardware buffer manager.
 @remarks
 This class is deliberately not a Singleton, so that multiple types can
 exist at once. The Singleton is wrapped via the Decorator pattern
 in HardwareBufferManager, below. Each concrete implementation should
 provide a subclass of HardwareBufferManagerBase, which does the actual
 work, and also a very simple subclass of HardwareBufferManager which
 simplyructs the instance of the HardwareBufferManagerBase subclass
 and passes it to the HardwareBufferManager superclass as a delegate.
 This subclass must also delete the implementation instance it creates.
 @todo Make NotImplementedError() functions abstract instead?
 */
class HardwareBufferManagerBase// : public BufferAlloc
{
protected:
    /** WARNING: The following two members should place before all other members.
     Members destruct order is very important here, because destructing other
     members will cause notify back to this class, and then will access to this
     two members.
     */
    //typedef set<HardwareVertexBuffer*>::type VertexBufferList;
    //typedef set<HardwareIndexBuffer*>::type IndexBufferList;
    //typedef set<HardwareUniformBuffer*>::type UniformBufferList;
    
    alias HardwareVertexBuffer[]  VertexBufferList;
    alias HardwareIndexBuffer[]   IndexBufferList;
    alias HardwareUniformBuffer[] UniformBufferList;
    alias HardwareCounterBuffer[] CounterBufferList;
    
    VertexBufferList mVertexBuffers;// = new mVertexBuffers;
    IndexBufferList mIndexBuffers;// = new IndexBufferList;
    UniformBufferList mUniformBuffers;// = new UniformBufferList;
    CounterBufferList mCounterBuffers;
    
    //typedef set<VertexDeclaration*>::type VertexDeclarationList;
    //typedef set<VertexBufferBinding*>::type VertexBufferBindingList;
    
    alias VertexDeclaration[] VertexDeclarationList;
    alias VertexBufferBinding[] VertexBufferBindingList;
    VertexDeclarationList mVertexDeclarations;
    VertexBufferBindingList mVertexBufferBindings;
    
    // Mutexes
    /*OGRE_MUTEX(mVertexBuffersMutex)
     OGRE_MUTEX(mIndexBuffersMutex)
     OGRE_MUTEX(mUniformBuffersMutex)
     OGRE_MUTEX(mVertexDeclarationsMutex)
     OGRE_MUTEX(mVertexBufferBindingsMutex)*/
    Mutex mVertexDeclarationsMutex, mVertexBufferBindingsMutex,
        mVertexBuffersMutex, mIndexBuffersMutex, mUniformBuffersMutex, mCounterBuffersMutex;
    
    
    /// Internal method for destroys all vertex declarations.
    void destroyAllDeclarations()
    {
        ////OGRE_LOCK_MUTEX(mVertexDeclarationsMutex)
        synchronized(mVertexDeclarationsMutex)
        {
            foreach (decl; mVertexDeclarations)
            {
                destroyVertexDeclarationImpl(decl);
            }
            mVertexDeclarations.clear();
        }
    }
    /// Internal method for destroys all vertex buffer bindings.
    void destroyAllBindings()
    {
        ////OGRE_LOCK_MUTEX(mVertexBufferBindingsMutex)
        synchronized(mVertexBufferBindingsMutex)
        {
            foreach (bind; mVertexBufferBindings)
            {
                destroyVertexBufferBindingImpl(bind);
            }
            mVertexBufferBindings.clear();
        }
    }
    
    /// Internal method for creates a new vertex declaration, may be overridden by certain rendering APIs.
    VertexDeclaration createVertexDeclarationImpl()
    {
        return new VertexDeclaration();
    }
    /// Internal method for destroys a vertex declaration, may be overridden by certain rendering APIs.
    void destroyVertexDeclarationImpl(ref VertexDeclaration decl)
    {
        destroy(decl);
    }
    
    /// Internal method for creates a new VertexBufferBinding, may be overridden by certain rendering APIs.
    VertexBufferBinding createVertexBufferBindingImpl()
    {
        return new VertexBufferBinding();
    }
    /// Internal method for destroys a VertexBufferBinding, may be overridden by certain rendering APIs.
    void destroyVertexBufferBindingImpl(ref VertexBufferBinding binding)
    {
        destroy(binding);
    }
    
public:
    
    enum BufferLicenseType
    {
        /// Licensee will only release buffer when it says so.
        BLT_MANUAL_RELEASE,
        /// Licensee can have license revoked.
        BLT_AUTOMATIC_RELEASE
    }
    
protected:
    /** Struct holding details of a license to use a temporary shared buffer. */
    class VertexBufferLicense
    {
    public:
        HardwareVertexBuffer originalBufferPtr;
        BufferLicenseType licenseType;
        size_t expiredDelay;
        SharedPtr!HardwareVertexBuffer buffer;
        HardwareBufferLicensee licensee;
        this(
            HardwareVertexBuffer orig,
            BufferLicenseType ltype,
            size_t delay,
            SharedPtr!HardwareVertexBuffer buf,
            HardwareBufferLicensee lic)
        {
            originalBufferPtr = orig;
            licenseType = ltype;
            expiredDelay = delay;
            buffer = buf;
            licensee = lic;
        }
        
    }
    
    /// Map from original buffer to temporary buffers.
    //typedef multimap<HardwareVertexBuffer*, SharedPtr!HardwareVertexBuffer>::type FreeTemporaryVertexBufferMap;
    //alias Array!SharedPtr!HardwareVertexBuffer[HardwareVertexBuffer] FreeTemporaryVertexBufferMap;
    //alias MultiMap!(HardwareVertexBuffer, SharedPtr!HardwareVertexBuffer) FreeTemporaryVertexBufferMap;
    alias SharedPtr!(HardwareVertexBuffer)[][HardwareVertexBuffer] FreeTemporaryVertexBufferMap;
    /// Map of current available temp buffers.
    FreeTemporaryVertexBufferMap mFreeTempVertexBufferMap;
    /// Map from temporary buffer to details of a license.
    //typedef map<HardwareVertexBuffer*, VertexBufferLicense>::type TemporaryVertexBufferLicenseMap;
    alias VertexBufferLicense[HardwareVertexBuffer] TemporaryVertexBufferLicenseMap;
    /// Map of currently licensed temporary buffers.
    TemporaryVertexBufferLicenseMap mTempVertexBufferLicenses;
    /// Number of frames elapsed since temporary buffers utilization was above half the available.
    size_t mUnderUsedFrameCount;
    /// Number of frames to wait before free unused temporary buffers.
    // Free temporary vertex buffers every 5 minutes on 100fps
    enum size_t UNDER_USED_FRAME_THRESHOLD = 30000;
    /// Frame delay for BLT_AUTOMATIC_RELEASE temporary buffers.
    enum size_t EXPIRED_DELAY_FRAME_THRESHOLD = 5;
    // Mutexes
    Mutex mTempBuffersMutex;
    
    
    /// Creates a new buffer as a copy of the source, does not copy data.
    SharedPtr!HardwareVertexBuffer makeBufferCopy(
        SharedPtr!HardwareVertexBuffer source,
        HardwareBuffer.Usage usage, bool useShadowBuffer)
    {
        return this.createVertexBuffer(
            source.get().getVertexSize(),
            source.get().getNumVertices(),
            usage, useShadowBuffer);
    }
    
public:
    this()
    {
        mUnderUsedFrameCount = 0;
        mTempBuffersMutex = new Mutex;
        mVertexDeclarationsMutex = new Mutex;
        mVertexBufferBindingsMutex = new Mutex;
        mVertexBuffersMutex = new Mutex;
        mIndexBuffersMutex = new Mutex;
        mUniformBuffersMutex = new Mutex;
        mCounterBuffersMutex = new Mutex;
    }
    ~this()
    {
        // Clear vertex/index buffer list first, avoid destroyed notify do
        // unnecessary work, and we'll destroy everything here.
        mVertexBuffers.clear();
        mIndexBuffers.clear();
        mUniformBuffers.clear();
        mCounterBuffers.clear();
        
        // Destroy everything
        destroyAllDeclarations();
        destroyAllBindings();
        // No need to destroy main buffers - they will be destroyed by removal of bindings
        
        // No need to destroy temp buffers - they will be destroyed automatically.
    }
    /** Create a hardware vertex buffer.
     @remarks
     This method creates a new vertex buffer; this will act as a source of geometry
     data for rendering objects. Note that because the meaning of the contents of
     the vertex buffer depends on the usage, this method does not specify a
     vertex format; the user of this buffer can actually insert whatever data
     they wish, in any format. However, in order to use this with a RenderOperation,
     the data in this vertex buffer will have to be associated with a semantic element
     of the rendering pipeline, e.g. a position, or texture coordinates. This is done
     using the VertexDeclaration class, which itself contains VertexElement structures
     ref erring to the source data.
     @remarks Note that because vertex buffers can be shared, they are reference
     counted so you do not need to worry about destroying themm this will be done
     automatically.
     @param vertexSize
     The size in bytes of each vertex in this buffer; you must calculate
     this based on the kind of data you expect to populate this buffer with.
     @param numVerts
     The number of vertices in this buffer.
     @param usage
     One or more members of the HardwareBuffer.Usage enumeration; you are
     strongly advised to use Usage.HBU_STATIC_WRITE_ONLY wherever possible, if you need to
     update regularly, consider Usage.HBU_DYNAMIC_WRITE_ONLY and useShadowBuffer=true.
     @param useShadowBuffer
     If set to @c true, this buffer will be 'shadowed' by one stored in
     system memory rather than GPU or AGP memory. You should set this flag if you intend
     to read data back from the vertex buffer, because reading data from a buffer
     in the GPU or AGP memory is very expensive, and is in fact impossible if you
     specify Usage.HBU_WRITE_ONLY for the main buffer. If you use this option, all
     reads and writes will be done to the shadow buffer, and the shadow buffer will
     be synchronised with the real buffer at an appropriate time.
     */
    SharedPtr!HardwareVertexBuffer
        createVertexBuffer(size_t vertexSize, size_t numVerts, HardwareBuffer.Usage usage,
                           bool useShadowBuffer = false)
    { throw new NotImplementedError(); }
    /** Create a hardware index buffer.
     @remarks Note that because buffers can be shared, they are reference
     counted so you do not need to worry about destroying them this will be done
     automatically.
     @param itype
     The type in index, either 16- or 32-bit, depending on how many vertices
     you need to be able to address
     @param numIndexes
     The number of indexes in the buffer
     @param usage
     One or more members of the HardwareBuffer.Usage enumeration.
     @param useShadowBuffer
     If set to @c true, this buffer will be 'shadowed' by one stored in
     system memory rather than GPU or AGP memory. You should set this flag if you intend
     to read data back from the index buffer, because reading data from a buffer
     in the GPU or AGP memory is very expensive, and is in fact impossible if you
     specify Usage.HBU_WRITE_ONLY for the main buffer. If you use this option, all
     reads and writes will be done to the shadow buffer, and the shadow buffer will
     be synchronised with the real buffer at an appropriate time.
     */
    SharedPtr!HardwareIndexBuffer
        createIndexBuffer(HardwareIndexBuffer.IndexType itype, size_t numIndexes,
                          HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    { throw new NotImplementedError(); }
    
    /** Create a render to vertex buffer.
     @remarks The parameters (such as vertex size etc) are determined later
     and are allocated when needed.
     */
    SharedPtr!RenderToVertexBuffer createRenderToVertexBuffer()
    { throw new NotImplementedError(); }
    
    /**
     * Create uniform buffer. This type of buffer allows the upload of shader constants once,
     * and sharing between shader stages or even shaders from another materials.
     * The update shall be triggered by GpuProgramParameters, if is dirty
     */
    SharedPtr!HardwareUniformBuffer createUniformBuffer(size_t sizeBytes,
                                                       HardwareBuffer.Usage usage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
                                                       bool useShadowBuffer = false,string name = "")
    { throw new NotImplementedError(); }
    
    /**
         * Create counter buffer.
         * The update shall be triggered by GpuProgramParameters, if is dirty
         */
    //abstract 
    SharedPtr!HardwareCounterBuffer createCounterBuffer(size_t sizeBytes,
                                                       HardwareBuffer.Usage usage = HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
                                                       bool useShadowBuffer = false, string name = "")
    { throw new NotImplementedError(); }
    
    /** Creates a new vertex declaration. */
    VertexDeclaration createVertexDeclaration()
    {
        VertexDeclaration decl = createVertexDeclarationImpl();
        synchronized(mVertexDeclarationsMutex)
            mVertexDeclarations.insert(decl);
        return decl;
    }
    /** Destroys a vertex declaration. */
    void destroyVertexDeclaration(ref VertexDeclaration decl)
    {
        synchronized(mVertexDeclarationsMutex)
        {
            mVertexDeclarations.removeFromArray(decl);
            destroyVertexDeclarationImpl(decl);
        }
    }
    
    /** Creates a new VertexBufferBinding. */
    VertexBufferBinding createVertexBufferBinding()
    {
        VertexBufferBinding ret = createVertexBufferBindingImpl();
        synchronized(mVertexBufferBindingsMutex)
            mVertexBufferBindings.insert(ret);
        return ret;
    }
    /** Destroys a VertexBufferBinding. */
    void destroyVertexBufferBinding(ref VertexBufferBinding binding)
    {
        synchronized(mVertexBufferBindingsMutex)
        {
            mVertexBufferBindings.removeFromArray(binding);
            destroyVertexBufferBindingImpl(binding);
        }
    }
    
    /** Registers a vertex buffer as a copy of another.
     @remarks
     This is useful for registering an existing buffer as a temporary buffer
     which can be allocated just like a copy.
     */
    void registerVertexBufferSourceAndCopy(
        SharedPtr!HardwareVertexBuffer sourceBuffer,
        SharedPtr!HardwareVertexBuffer copy)
    {
        synchronized(mTempBuffersMutex)
        {
            //TODO move null check?
            mFreeTempVertexBufferMap.initAA(sourceBuffer.get());
            // Add copy to free temporary vertex buffers
            mFreeTempVertexBufferMap[sourceBuffer.get()] ~= copy;
        }
    }
    
    /** Allocates a copy of a given vertex buffer.
     @remarks
     This method allocates a temporary copy of an existing vertex buffer.
     This buffer is subsequently stored and can be made available for
     other purposes later without incurring the cost of construction /
     destruction.
     @param sourceBuffer
     The source buffer to use as a copy.
     @param licenseType
     The type of license required on this buffer - automatic
     release causes this class to release licenses every frame so that
     they can be reallocated anew.
     @param licensee
     Pointer back to the class requesting the copy, which must
     implement HardwareBufferLicense in order to be notified when the license
     expires.
     @param copyData
     If @c true, the current data is copied as well as the
     structure of the buffer/
     */
    SharedPtr!HardwareVertexBuffer allocateVertexBufferCopy(
        SharedPtr!HardwareVertexBuffer sourceBuffer,
        BufferLicenseType licenseType,
        HardwareBufferLicensee licensee,
        bool copyData = false)
    {
        // pre-lock the mVertexBuffers mutex, which would usually get locked in
        //  makeBufferCopy / createVertexBuffer
        // this prevents a deadlock in _notifyVertexBufferDestroyed
        // which locks the same mutexes (via other methods) but in reverse order
        synchronized(mVertexBuffersMutex)
        {
            synchronized(mTempBuffersMutex)
            {
                SharedPtr!HardwareVertexBuffer vbuf;
                
                // Locate existing buffer copy in temporary vertex buffers
                //auto i = sourceBuffer.get() in mFreeTempVertexBufferMap;
                //if (i is null)
                if ((sourceBuffer.get() in mFreeTempVertexBufferMap) !is null &&
                    mFreeTempVertexBufferMap[sourceBuffer.get()].length)
                {
                    // copy buffer, use shadow buffer and make dynamic
                    vbuf = makeBufferCopy(
                        sourceBuffer,
                        HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE,
                        true);
                }
                else
                {
                    // Allocate existing copy
                    //vbuf = *i;
                    //mFreeTempVertexBufferMap.remove(sourceBuffer.get());

                    vbuf = mFreeTempVertexBufferMap[sourceBuffer.get()][0];
                    mFreeTempVertexBufferMap[sourceBuffer.get()].removeFromArrayIdx(0);

                }
                
                // Copy data?
                if (copyData)
                {
                    vbuf.get().copyData(sourceBuffer.get(), 0, 0, sourceBuffer.get().getSizeInBytes(), true);
                }
                
                // Insert copy into licensee list
                mTempVertexBufferLicenses[vbuf.get()] =
                    new VertexBufferLicense(sourceBuffer.get(), licenseType, EXPIRED_DELAY_FRAME_THRESHOLD, vbuf, licensee);
                return vbuf;
            }
        }
    }
    
    /** Manually release a vertex buffer copy for others to subsequently use.
     @remarks
     Only required if the original call to allocateVertexBufferCopy
     included a licenseType of BLT_MANUAL_RELEASE.
     @param bufferCopy
     The buffer copy. The caller is expected to delete
     or at least no longer use this reference, since another user may
     well begin to modify the contents of the buffer.
     */
    void releaseVertexBufferCopy(
        SharedPtr!HardwareVertexBuffer bufferCopy)
    {
        synchronized(mTempBuffersMutex)
        {
            auto i = bufferCopy.get() in mTempVertexBufferLicenses;
            if (i !is null)
            {
                VertexBufferLicense vbl = *i;
                
                vbl.licensee.licenseExpired(vbl.buffer.get());

                mTempVertexBufferLicenses.remove(bufferCopy.get());
                mFreeTempVertexBufferMap[vbl.originalBufferPtr] ~= vbl.buffer;
            }
        }
    }
    
    /** Tell engine that the vertex buffer copy intent to reuse.
     @remarks
     Ogre internal keep an expired delay counter of BLT_AUTOMATIC_RELEASE
     buffers, when the counter count down to zero, it'll release for other
     purposes later. But you can use this function to reset the counter to
     the internal configured value, keep the buffer not get released for
     some frames.
     @param bufferCopy
     The buffer copy. The caller is expected to keep this
     buffer copy for use.
     */
    void touchVertexBufferCopy(SharedPtr!HardwareVertexBuffer bufferCopy)
    {
        synchronized(mTempBuffersMutex)
        {
            auto i = bufferCopy.get() in mTempVertexBufferLicenses;
            if (i !is null)
            {
                VertexBufferLicense vbl = *i;
                assert(vbl.licenseType == BufferLicenseType.BLT_AUTOMATIC_RELEASE);
                
                vbl.expiredDelay = EXPIRED_DELAY_FRAME_THRESHOLD;
            }
        }
    }
    
    /** Free all unused vertex buffer copies.
     @remarks
     This method free all temporary vertex buffers that not in used.
     In normally, temporary vertex buffers are subsequently stored and can
     be made available for other purposes later without incurring the cost
     of construction / destruction. But in some cases you want to free them
     to save hardware memory (e.g. application was runs in a long time, you
     might free temporary buffers periodically to avoid memory overload).
     */
    void _freeUnusedBufferCopies()
    {
        synchronized(mTempBuffersMutex)
        {
            size_t numFreed = 0;

            //MultiMap fuckery
            // Free unused temporary buffers
            foreach (k; mFreeTempVertexBufferMap.keys)
            {
                auto arr = mFreeTempVertexBufferMap[k];
                for(size_t idx = 0; idx < arr.length; )
                {
                    auto curr = arr[idx];
                    // Free the temporary buffer that referenced by ourself only.
                    // TODO: Some temporary buffers are bound to vertex buffer bindings
                    // but not checked out, need to sort out method to unbind them.
                    if (curr.useCount() <= 1)
                    {
                        ++numFreed;
                        mFreeTempVertexBufferMap[k].removeFromArrayIdx(idx);
                    }
                    else
                        idx++;
                }
            }
            
            string str;
            if (numFreed)
            {
                str = "HardwareBufferManager: Freed " ~ to!string(numFreed) ~ " unused temporary vertex buffers.";
            }
            else
            {
                str = "HardwareBufferManager: No unused temporary vertex buffers found.";
            }
            LogManager.getSingleton().logMessage(str, LML_TRIVIAL);
        }
    }
    
    /** Internal method for releasing all temporary buffers which have been
     allocated using BLT_AUTOMATIC_RELEASE; is called by OGRE.
     @param forceFreeUnused
     If @c true, free all unused temporary buffers.
     If @c false, auto detect and free all unused temporary buffers based on
     temporary buffers utilization.
     */
    void _releaseBufferCopies(bool forceFreeUnused = false)
    {
        synchronized(mTempBuffersMutex)
        {
            size_t numUnused = mFreeTempVertexBufferMap.length;
            size_t numUsed = mTempVertexBufferLicenses.length;
            
            // Erase the copies which are automatic licensed out
            foreach (k; mTempVertexBufferLicenses.keys)
            {
                auto vbl = mTempVertexBufferLicenses[k];

                if (vbl.licenseType == BufferLicenseType.BLT_AUTOMATIC_RELEASE &&
                    (forceFreeUnused || --vbl.expiredDelay <= 0))
                {
                    vbl.licensee.licenseExpired(vbl.buffer.get());
                    
                    mFreeTempVertexBufferMap.initAA(vbl.originalBufferPtr);
                    mFreeTempVertexBufferMap[vbl.originalBufferPtr] ~= vbl.buffer;
                    mTempVertexBufferLicenses.remove(k);
                }
            }
            
            // Check whether or not free unused temporary vertex buffers.
            if (forceFreeUnused)
            {
                _freeUnusedBufferCopies();
                mUnderUsedFrameCount = 0;
            }
            else
            {
                if (numUsed < numUnused)
                {
                    // Free temporary vertex buffers if too many unused for a long time.
                    // Do overall temporary vertex buffers instead of per source buffer
                    // to avoid overhead.
                    ++mUnderUsedFrameCount;
                    if (mUnderUsedFrameCount >= UNDER_USED_FRAME_THRESHOLD)
                    {
                        _freeUnusedBufferCopies();
                        mUnderUsedFrameCount = 0;
                    }
                }
                else
                {
                    mUnderUsedFrameCount = 0;
                }
            }
        }
    }
    
    /** Internal method that forces the release of copies of a given buffer.
     @remarks
     This usually means that the buffer which the copies are based on has
     been changed in some fundamental way, and the owner of the original
     wishes to make that known so that new copies will reflect the
     changes.
     @param sourceBuffer
     The source buffer as a shared pointer.  Any buffer copies created
     from the source buffer are deleted.
     */
    void _forceReleaseBufferCopies(SharedPtr!HardwareVertexBuffer sourceBuffer)
    {
        _forceReleaseBufferCopies(sourceBuffer.get());
    }
    
    /** Internal method that forces the release of copies of a given buffer.
     @remarks
     This usually means that the buffer which the copies are based on has
     been changed in some fundamental way, and the owner of the original
     wishes to make that known so that new copies will reflect the
     changes.
     @param sourceBuffer
     The source buffer as a pointer. Any buffer copies created from
     the source buffer are deleted.
     */
    void _forceReleaseBufferCopies(HardwareVertexBuffer sourceBuffer)
    {
        synchronized(mTempBuffersMutex)
        {
            // Erase the copies which are licensed out
            foreach (k; mTempVertexBufferLicenses.keys)
            {
                auto vbl = mTempVertexBufferLicenses[k];
                if (vbl.originalBufferPtr == sourceBuffer)
                {
                    // Just tell the owner that this is being released
                    vbl.licensee.licenseExpired(vbl.buffer.get());
                    
                    mTempVertexBufferLicenses.remove(k); //FIXME delete?
                }
            }
            
            // Erase the free copies
            //
            // Why we need this unusual code? It's for resolve reenter problem.
            //
            // Using mFreeTempVertexBufferMap.erase(sourceBuffer) directly will
            // cause reenter into here because vertex buffer destroyed notify.
            // In most time there are no problem. But when sourceBuffer is the
            // last item of the mFreeTempVertexBufferMap, some STL multimap
            // implementation (VC and STLport) will call to clear(), which will
            // causing intermediate state of mFreeTempVertexBufferMap, in that
            // time destroyed notify back to here cause illegal accessing in
            // the end.
            //
            // For safely reason, use following code to resolve reenter problem.
            //
            /*typedef FreeTemporaryVertexBufferMap.iterator _Iter;
             std.pair<_Iter, _Iter> range = mFreeTempVertexBufferMap.equal_range(sourceBuffer);
             if (range.first != range.second)
             {
             list<SharedPtr!HardwareVertexBuffer>::type holdForDelayDestroy;
             for (_Iter it = range.first; it != range.second; ++it)
             {
             if (it.second.useCount() <= 1)
             {
             holdForDelayDestroy.insertBack(it.second);
             }
             }

             mFreeTempVertexBufferMap.erase(range.first, range.second);

             // holdForDelayDestroy will destroy auto.
             }*/
            
            //FIXME destroy?
            if((sourceBuffer in mFreeTempVertexBufferMap) !is null)
            {
                auto arr = mFreeTempVertexBufferMap[sourceBuffer];
                mFreeTempVertexBufferMap.remove(sourceBuffer);
    
                foreach(i; arr)
                    destroy(i);
                destroy(arr);
            }
            else
            {
                debug(STDERR) std.stdio.stderr.writeln("_forceReleaseBufferCopies:", sourceBuffer, " not in mFreeTempVertexBufferMap");
            }
        }
    }
    
    /// Notification that a hardware vertex buffer has been destroyed.
    void _notifyVertexBufferDestroyed(HardwareVertexBuffer buf)
    {
        synchronized(mVertexBuffersMutex)
        {
            auto i = std.algorithm.find(mVertexBuffers, buf);
            if (!i.empty())
            {
                // release vertex buffer copies
                mVertexBuffers.removeFromArray(buf);
                _forceReleaseBufferCopies(buf);
            }
        }
    }
    /// Notification that a hardware index buffer has been destroyed.
    void _notifyIndexBufferDestroyed(HardwareIndexBuffer buf)
    {
        synchronized(mIndexBuffersMutex)
        {
            auto i = std.algorithm.find(mIndexBuffers, buf);
            if (!i.empty())
            {
                mIndexBuffers.removeFromArray(buf);
            }
        }
    }
    /// Notification that at hardware uniform buffer has been destroyed
    void _notifyUniformBufferDestroyed(HardwareUniformBuffer buf)
    {
    }
    
    void _notifyCounterBufferDestroyed(HardwareCounterBuffer buf)
    {
    }
    
}

/** Singleton wrapper for hardware buffer manager. */
class HardwareBufferManager : HardwareBufferManagerBase//, Singleton<HardwareBufferManager>
{
    alias HardwareBufferManagerBase._forceReleaseBufferCopies _forceReleaseBufferCopies;
    
    //FIXME Because the nature of Singleton template right now, derived classes don't work very well
    //Call singleton through HardwareBufferManager and pass implementation as getSingletonInit!Type(Arg) template argument.
    mixin Singleton!HardwareBufferManager;

    //friend class SharedPtr!HardwareVertexBuffer;
    //friend class SharedPtr!HardwareIndexBuffer;
protected:
    HardwareBufferManagerBase mImpl;
    /**
       For Singleton's use only!
     **/
    this() {}
    
public:

    

    this(HardwareBufferManagerBase imp)
    {
        super();
        mImpl = imp;
    }

    ~this()
    {
        // mImpl must be deleted by the creator
    }
    
    /** @copydoc HardwareBufferManagerBase.createVertexBuffer */
    override SharedPtr!HardwareVertexBuffer
        createVertexBuffer(size_t vertexSize, size_t numVerts, HardwareBuffer.Usage usage,
                           bool useShadowBuffer = false)
    {
        return mImpl.createVertexBuffer(vertexSize, numVerts, usage, useShadowBuffer);
    }
    /** @copydoc HardwareBufferManagerBase.createIndexBuffer */
    override SharedPtr!HardwareIndexBuffer
        createIndexBuffer(HardwareIndexBuffer.IndexType itype, size_t numIndexes,
                          HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        return mImpl.createIndexBuffer(itype, numIndexes, usage, useShadowBuffer);
    }
    
    /** @copydoc HardwareBufferManagerBase.createRenderToVertexBuffer */
    override SharedPtr!RenderToVertexBuffer createRenderToVertexBuffer()
    {
        return mImpl.createRenderToVertexBuffer();
    }
    
    /** @copydoc HardwareBufferManagerBase.createUniformBuffer */
    override SharedPtr!HardwareUniformBuffer
        createUniformBuffer(size_t sizeBytes, HardwareBuffer.Usage usage, bool useShadowBuffer,string name = "")
    {
        return mImpl.createUniformBuffer(sizeBytes, usage, useShadowBuffer, name);
    }
    
    /** @copydoc HardwareBufferManagerBase.createCounterBuffer */
    override SharedPtr!HardwareCounterBuffer
        createCounterBuffer(size_t sizeBytes, HardwareBuffer.Usage usage, bool useShadowBuffer, string name = "")
    {
        return mImpl.createCounterBuffer(sizeBytes, usage, useShadowBuffer, name);
    }
    
    /** @copydoc HardwareBufferManagerInterface.createVertexDeclaration */
    override VertexDeclaration createVertexDeclaration()
    {
        return mImpl.createVertexDeclaration();
    }
    /** @copydoc HardwareBufferManagerBase.destroyVertexDeclaration */
    override void destroyVertexDeclaration(ref VertexDeclaration decl)
    {
        mImpl.destroyVertexDeclaration(decl);
    }
    
    /** @copydoc HardwareBufferManagerBase.createVertexBufferBinding */
    override VertexBufferBinding createVertexBufferBinding()
    {
        return mImpl.createVertexBufferBinding();
    }
    /** @copydoc HardwareBufferManagerBase.destroyVertexBufferBinding */
    override void destroyVertexBufferBinding(ref VertexBufferBinding binding)
    {
        mImpl.destroyVertexBufferBinding(binding);
    }
    /** @copydoc HardwareBufferManagerBase.registerVertexBufferSourceAndCopy */
    override void registerVertexBufferSourceAndCopy(
        SharedPtr!HardwareVertexBuffer sourceBuffer,
        SharedPtr!HardwareVertexBuffer copy)
    {
        mImpl.registerVertexBufferSourceAndCopy(sourceBuffer, copy);
    }
    /** @copydoc HardwareBufferManagerBase.allocateVertexBufferCopy */
    override SharedPtr!HardwareVertexBuffer allocateVertexBufferCopy(
        SharedPtr!HardwareVertexBuffer sourceBuffer,
        BufferLicenseType licenseType,
        HardwareBufferLicensee licensee,
        bool copyData = false)
    {
        return mImpl.allocateVertexBufferCopy(sourceBuffer, licenseType, licensee, copyData);
    }
    /** @copydoc HardwareBufferManagerBase.releaseVertexBufferCopy */
    override void releaseVertexBufferCopy(
        SharedPtr!HardwareVertexBuffer bufferCopy)
    {
        mImpl.releaseVertexBufferCopy(bufferCopy);
    }
    
    /** @copydoc HardwareBufferManagerBase.touchVertexBufferCopy */
    override void touchVertexBufferCopy(
        SharedPtr!HardwareVertexBuffer bufferCopy)
    {
        mImpl.touchVertexBufferCopy(bufferCopy);
    }
    
    /** @copydoc HardwareBufferManagerBase._freeUnusedBufferCopies */
    override void _freeUnusedBufferCopies()
    {
        mImpl._freeUnusedBufferCopies();
    }
    /** @copydoc HardwareBufferManagerBase._releaseBufferCopies */
    override void _releaseBufferCopies(bool forceFreeUnused = false)
    {
        mImpl._releaseBufferCopies(forceFreeUnused);
    }
    /** @copydoc HardwareBufferManagerBase._forceReleaseBufferCopies */
    override void _forceReleaseBufferCopies(HardwareVertexBuffer sourceBuffer)
    {
        mImpl._forceReleaseBufferCopies(sourceBuffer);
    }
    /** @copydoc HardwareBufferManagerBase._notifyVertexBufferDestroyed */
    override void _notifyVertexBufferDestroyed(HardwareVertexBuffer buf)
    {
        mImpl._notifyVertexBufferDestroyed(buf);
    }
    /** @copydoc HardwareBufferManagerBase._notifyIndexBufferDestroyed */
    override void _notifyIndexBufferDestroyed(HardwareIndexBuffer buf)
    {
        mImpl._notifyIndexBufferDestroyed(buf);
    }
    /** @copydoc HardwareBufferManagerInterface._notifyIndexBufferDestroyed */
    override void _notifyUniformBufferDestroyed(HardwareUniformBuffer buf)
    {
        mImpl._notifyUniformBufferDestroyed(buf);
    }
    /** @copydoc HardwareBufferManagerInterface._notifyCounterBufferDestroyed */
    override void _notifyCounterBufferDestroyed(HardwareCounterBuffer buf)
    {
        mImpl._notifyCounterBufferDestroyed(buf);
    }
}



/** Specialisation of HardwareBuffer for a vertex buffer. */
class HardwareVertexBuffer : HardwareBuffer
{
protected:
    
    HardwareBufferManagerBase mMgr;
    size_t mNumVertices;
    size_t mVertexSize;
    bool mIsInstanceData;
    size_t mInstanceDataStepRate;
    /// Checks if vertex instance data is supported by the render system
    bool checkIfVertexInstanceDataIsSupported()
    {
        // Use the current render system
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        
        // Check if the supported
        return rs.getCapabilities().hasCapability(Capabilities.RSC_VERTEX_BUFFER_INSTANCE_DATA);
    }
    
public:
    /// Should be called by HardwareBufferManager
    this(HardwareBufferManagerBase mgr, size_t vertexSize, size_t numVertices,
         HardwareBuffer.Usage usage, bool useSystemMemory, bool useShadowBuffer)
    {
        super(usage, useSystemMemory, useShadowBuffer);
        mMgr = mgr;
        mNumVertices = numVertices;
        mVertexSize = vertexSize;
        mIsInstanceData = false;
        mInstanceDataStepRate = 1;
        // Calculate the size of the vertices
        mSizeInBytes = mVertexSize * numVertices;
        
        // Create a shadow buffer if required
        if (mUseShadowBuffer)
        {
            mShadowBuffer = new DefaultHardwareVertexBuffer(mMgr, mVertexSize,
                                                            mNumVertices, HardwareBuffer.Usage.HBU_DYNAMIC);
        }
        
    }
    ~this()
    {
        if (mMgr)
        {
            debug(STDERR) std.stdio.stderr.writeln("~HardwareVertexBuffer: ", &this);
            mMgr._notifyVertexBufferDestroyed(this);
        }
        if (mShadowBuffer)
        {
            destroy(mShadowBuffer);
        }
    }
    /// Return the manager of this buffer, if any
    ref HardwareBufferManagerBase getManager(){ return mMgr; }
    /// Gets the size in bytes of a single vertex in this buffer
    size_t getVertexSize() const { return mVertexSize; }
    /// Get the number of vertices in this buffer
    size_t getNumVertices() const { return mNumVertices; }
    /// Get if this vertex buffer is an "instance data" buffer (per instance)
    bool getIsInstanceData() const { return mIsInstanceData; }
    /// Set if this vertex buffer is an "instance data" buffer (per instance)
    void setIsInstanceData(bool val)
    {
        if (val && !checkIfVertexInstanceDataIsSupported())
        {
            throw new RenderingApiError(
                "vertex instance data is not supported by the render system.",
                "HardwareVertexBuffer.checkIfInstanceDataSupported");
        }
        else
        {
            mIsInstanceData = val;
        }
    }
    /// Get the number of instances to draw using the same per-instance data before advancing in the buffer by one element.
    size_t getInstanceDataStepRate()
    {
        return mInstanceDataStepRate;
    }
    /// Set the number of instances to draw using the same per-instance data before advancing in the buffer by one element.
    void setInstanceDataStepRate(size_t val)
    {
        if (val > 0)
        {
            mInstanceDataStepRate = val;
        }
        else
        {
            throw new RenderingApiError(
                "Instance data step rate must be bigger then 0.",
                "HardwareVertexBuffer.setInstanceDataStepRate");
        }
    }
    
    
    // NB subclasses should override lock, unlock, readData, writeData
    
}

/** Shared pointer implementation used to share index buffers. */
//alias SharedPtr!HardwareVertexBuffer HardwareVertexBufferSharedPtr;

/*class _HardwareVertexBufferSharedPtr : SharedPtr!HardwareVertexBuffer
{
public:
    this() { super() ;}
    this(ref HardwareVertexBuffer buf)
    {
        super(buf);
    }

    //override HardwareVertexBuffer get()
}*/

/** Locking helper. */
alias HardwareBufferLockGuard!(SharedPtr!HardwareVertexBuffer) HardwareVertexBufferLockGuard;

/** Specialisation of HardwareBuffer for vertex index buffers, still abstract. */
class HardwareIndexBuffer : HardwareBuffer
{
public:
    enum IndexType {
        IT_16BIT,
        IT_32BIT
    }
    
protected:
    HardwareBufferManagerBase mMgr;
    IndexType mIndexType;
    size_t mNumIndexes;
    size_t mIndexSize;
    
public:
    /// Should be called by HardwareBufferManager
    this(HardwareBufferManagerBase mgr, IndexType idxType, size_t numIndexes, HardwareBuffer.Usage usage,
         bool useSystemMemory, bool useShadowBuffer)
    {
        super(usage, useSystemMemory, useShadowBuffer);
        mMgr = mgr;
        mIndexType = idxType;
        mNumIndexes = numIndexes;
        
        // Calculate the size of the indexes
        final switch (mIndexType)
        {
            case IndexType.IT_16BIT:
                mIndexSize = ushort.sizeof;
                break;
            case IndexType.IT_32BIT:
                mIndexSize = uint.sizeof;
                break;
        }
        mSizeInBytes = mIndexSize * mNumIndexes;
        
        // Create a shadow buffer if required
        if (mUseShadowBuffer)
        {
            mShadowBuffer = new DefaultHardwareIndexBuffer(mIndexType, 
                                                           mNumIndexes, HardwareBuffer.Usage.HBU_DYNAMIC);
        }
    }
    ~this()
    {
        if (mMgr)
        {
            mMgr._notifyIndexBufferDestroyed(this);
        }
        
        if (mShadowBuffer)
        {
            destroy(mShadowBuffer);
        }
    }
    /// Return the manager of this buffer, if any
    ref HardwareBufferManagerBase getManager(){ return mMgr; }
    /// Get the type of indexes used in this buffer
    IndexType getType() const { return mIndexType; }
    /// Get the number of indexes in this buffer
    size_t getNumIndexes() const { return mNumIndexes; }
    /// Get the size in bytes of each index
    size_t getIndexSize() const { return mIndexSize; }
    
    // NB subclasses should override lock, unlock, readData, writeData
}


/** Shared pointer implementation used to share index buffers. */
//alias SharedPtr!HardwareIndexBuffer HardwareIndexBufferPtr;
/*class _SharedPtr!HardwareIndexBuffer : SharedPtr!HardwareIndexBuffer
{
public:
    this() { super(); }
    this(ref HardwareIndexBuffer buf){ super(buf); }
}*/

/** Locking helper. */    
alias HardwareBufferLockGuard!(SharedPtr!HardwareIndexBuffer) HardwareIndexBufferLockGuard;



/** Specialisation of HardwareBuffer for a pixel buffer. The
 HardwarePixelbuffer abstracts an 1D, 2D or 3D quantity of pixels
 stored by the rendering API. The buffer can be located on the card
 or in main memory depending on its usage. One mipmap level of a
 texture is an example of a HardwarePixelBuffer.
 */
class HardwarePixelBuffer : HardwareBuffer
{
public:
    /** Notify TextureBuffer of destruction of render target.
     Called by RenderTexture when destroyed.
     */
    //public for friendly RenderTexture
    void _clearSliceRTT(size_t zoffset) {}

protected: 
    // Extents
    size_t mWidth, mHeight, mDepth;
    // Pitches (offsets between rows and slices)
    size_t mRowPitch, mSlicePitch;
    // Internal format
    PixelFormat mFormat;
    // Currently locked region (local coords)
    PixelBox mCurrentLock;
    // The current locked box of this surface (entire surface coords)
    Image.Box mLockedBox;
    
    
    /// Internal implementation of lock(), must be overridden in subclasses
    // TODO const(Image.Box) ?
    abstract PixelBox lockImpl(Image.Box lockBox,  LockOptions options);
    
    /// Internal implementation of lock(), do not OVERRIDE or CALL this
    /// for HardwarePixelBuffer implementations, but override the previous method
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        throw new InternalError( "lockImpl(offset,length) is not valid for PixelBuffers and should never be called",
                                "HardwarePixelBuffer.lockImpl");
    }
    
    /// Internal implementation of unlock(), must be overridden in subclasses
    //abstract void unlockImpl(); //FIXME base class has already

    //friend class RenderTexture;
public:
    /// Should be called by HardwareBufferManager
    this(size_t mWidth, size_t mHeight, size_t mDepth,
         PixelFormat mFormat,
         HardwareBuffer.Usage usage, bool useSystemMemory, bool useShadowBuffer)
    {
        super(usage, useSystemMemory, useShadowBuffer);
        // Default
        mRowPitch = mWidth;
        mSlicePitch = mHeight*mWidth;
        mSizeInBytes = mHeight*mWidth*PixelUtil.getNumElemBytes(mFormat);
    }
    
    ~this() {}
    
    /** make every lock method from HardwareBuffer available.
     See http://www.research.att.com/~bs/bs_faq2.html#overloadderived
     */
    //using HardwareBuffer::lock; 
    alias HardwareBuffer.lock lock; //???
    
    /** Lock the buffer for (potentially) reading / writing.
     @param lockBox Region of the buffer to lock
     @param options Locking options
     @return PixelBox containing the locked region, the pitches and
     the pixel format
     */
    PixelBox lock(Image.Box lockBox, LockOptions options)
    {
        if (mUseShadowBuffer)
        {
            if (options != HardwareBuffer.LockOptions.HBL_READ_ONLY)
            {
                // we have to assume a read / write lock so we use the shadow buffer
                // and tag for sync on unlock()
                mShadowUpdated = true;
            }
            
            mCurrentLock = (cast(HardwarePixelBuffer*)mShadowBuffer).lock(lockBox, options);
        }
        else
        {
            // Lock the real buffer if there is no shadow buffer 
            mCurrentLock = lockImpl(lockBox, options);
            mIsLocked = true;
        }
        
        return mCurrentLock;
    }
    
    /// @copydoc HardwareBuffer::lock
    override void* lock(size_t offset, size_t length, LockOptions options)
    {
        assert(!isLocked() , "Cannot lock this buffer, it is already locked!");
        assert(offset == 0 && length == mSizeInBytes , "Cannot lock memory region, most lock box or entire buffer");
        
        auto myBox = new Image.Box(0, 0, 0, mWidth, mHeight, mDepth);
        PixelBox rv = lock(myBox, options);
        return rv.data;
    }
    
    /** Get the current locked region. This is the same value as returned
     by lock(Image::Box, LockOptions)
     @return PixelBox containing the locked region
     */        
    ref PixelBox getCurrentLock()
    { 
        assert(isLocked() , "Cannot get current lock: buffer not locked");
        
        return mCurrentLock; 
    }
    
    /// @copydoc HardwareBuffer::readData
    override void readData(size_t offset, size_t length, void* pDest)
    {
        // TODO
        throw new NotImplementedError(
            "Reading a byte range is not implemented. Use blitToMemory.",
            "HardwarePixelBuffer.readData");
    }
    /// @copydoc HardwareBuffer::writeData
    override void writeData(size_t offset, size_t length,void* pSource,
                            bool discardWholeBuffer = false)
    {
        // TODO
        throw new NotImplementedError(
            "Writing a byte range is not implemented. Use blitFromMemory.",
            "HardwarePixelBuffer.writeData");
    }
    
    /** Copies a box from another PixelBuffer to a region of the 
     this PixelBuffer. 
     @param src      Source pixel buffer
     @param srcBox   Image::Box describing the source region in src
     @param dstBox   Image::Box describing the destination region in this buffer
     @remarks The source and destination regions dimensions don't have to match, in which
     case scaling is done. This scaling is generally done using a bilinear filter in hardware,
     but it is faster to pass the source image in the right dimensions.
     @note Only call this function when both  buffers are unlocked. 
     */        
    void blit(SharedPtr!HardwarePixelBuffer src, Image.Box srcBox, Image.Box dstBox)
    {
        if(isLocked() || src.get().isLocked())
        {
            throw new InternalError(
                "Source and destination buffer may not be locked!",
                "HardwarePixelBuffer.blit");
        }
        if(src.getPointer() == this)
        {
            throw new InvalidParamsError(
                "Source must not be the same object",
                "HardwarePixelBuffer.blit" ) ;
        }
        PixelBox srclock = src.get().lock(srcBox, LockOptions.HBL_READ_ONLY);
        
        LockOptions method = LockOptions.HBL_NORMAL;
        if(dstBox.left == 0 && dstBox.top == 0 && dstBox.front == 0 &&
           dstBox.right == mWidth && dstBox.bottom == mHeight &&
           dstBox.back == mDepth)
            // Entire buffer -- we can discard the previous contents
            method = LockOptions.HBL_DISCARD;
        
        PixelBox dstlock = lock(dstBox, method);
        if(dstlock.getWidth() != srclock.getWidth() ||
           dstlock.getHeight() != srclock.getHeight() ||
           dstlock.getDepth() != srclock.getDepth())
        {
            // Scaling desired
            Image.scale(srclock, dstlock);
        }
        else
        {
            // No scaling needed
            PixelUtil.bulkPixelConversion(srclock, dstlock);
        }
        
        unlock();
        src.get().unlock();
    }
    
    /** Convenience function that blits the entire source pixel buffer to this buffer. 
     If source and destination dimensions don't match, scaling is done.
     @param src      PixelBox containing the source pixels and format in memory
     @note Only call this function when the buffer is unlocked. 
     */
    void blit(SharedPtr!HardwarePixelBuffer src)
    {
        blit(src, 
             new Box(0,0,0,src.get().getWidth(),src.get().getHeight(),src.get().getDepth()), 
             new Box(0,0,0,mWidth,mHeight,mDepth)
             );
    }
    
    /** Copies a region from normal memory to a region of this pixelbuffer. The source
     image can be in any pixel format supported by OGRE, and in any size. 
     @param src      PixelBox containing the source pixels and format in memory
     @param dstBox   Image::Box describing the destination region in this buffer
     @remarks The source and destination regions dimensions don't have to match, in which
     case scaling is done. This scaling is generally done using a bilinear filter in hardware,
     but it is faster to pass the source image in the right dimensions.
     @note Only call this function when the buffer is unlocked. 
     */
    abstract void blitFromMemory(PixelBox src, Image.Box dstBox);
    
    /** Convenience function that blits a pixelbox from memory to the entire 
     buffer. The source image is scaled as needed.
     @param src      PixelBox containing the source pixels and format in memory
     @note Only call this function when the buffer is unlocked. 
     */
    void blitFromMemory(PixelBox src)
    {
        blitFromMemory(src, new Box(0,0,0,mWidth,mHeight,mDepth));
    }
    
    /** Copies a region of this pixelbuffer to normal memory.
     @param srcBox   Image::Box describing the source region of this buffer
     @param dst      PixelBox describing the destination pixels and format in memory
     @remarks The source and destination regions don't have to match, in which
     case scaling is done.
     @note Only call this function when the buffer is unlocked. 
     */
    abstract void blitToMemory(Image.Box srcBox, ref PixelBox dst);
    //abstract void blitToMemory(const(Image.Box) srcBox, PixelBox dst); //TODO maybe
    
    /** Convience function that blits this entire buffer to a pixelbox.
     The image is scaled as needed.
     @param dst      PixelBox describing the destination pixels and format in memory
     @note Only call this function when the buffer is unlocked. 
     */
    void blitToMemory(PixelBox dst)
    {
        blitToMemory(new Box(0,0,0,mWidth,mHeight,mDepth), dst);
    }
    
    /** Get a render target for this PixelBuffer, or a slice of it. The texture this
     was acquired from must have TU_RENDERTARGET set, otherwise it is possible to
     render to it and this method will throw an ERR_RENDERSYSTEM exception.
     @param slice    Which slice
     @return A pointer to the render target. This pointer has the lifespan of this
     PixelBuffer.
     */
    RenderTexture getRenderTarget(size_t slice=0)
    {
        throw new NotImplementedError(
            "Not yet implemented for this rendersystem.",
            "HardwarePixelBuffer.getRenderTarget");
    }
    
    /// Gets the width of this buffer
    size_t getWidth(){ return mWidth; }
    /// Gets the height of this buffer
    size_t getHeight(){ return mHeight; }
    /// Gets the depth of this buffer
    size_t getDepth(){ return mDepth; }
    /// Gets the native pixel format of this buffer
    PixelFormat getFormat(){ return mFormat; }
}

/** Shared pointer implementation used to share pixel buffers. */
//alias SharedPtr!HardwarePixelBuffer HardwarePixelBufferPtr;
/*class _SharedPtr!HardwarePixelBuffer : SharedPtr!HardwarePixelBuffer
{
public:
    this() {}
    this(ref HardwarePixelBuffer buf)
    {
        super(buf);
    }
}*/

/** Specialisation of HardwareBuffer for a vertex buffer. */
class HardwareUniformBuffer : HardwareBuffer
{
protected:
    HardwareBufferManagerBase mMgr;
    string mName;
    
public:
    /// Should be called by HardwareBufferManager
    this(ref HardwareBufferManagerBase mgr, size_t sizeBytes,
         HardwareBuffer.Usage usage, bool useShadowBuffer = false,string name = "")
    {
        super(usage, false, useShadowBuffer);
        mName = name;
        // Calculate the size of the vertices
        mSizeInBytes = sizeBytes;
        
        // Create a shadow buffer if required
        if (mUseShadowBuffer)
        {
            mShadowBuffer = new DefaultHardwareUniformBuffer(mMgr, sizeBytes, HardwareBuffer.Usage.HBU_DYNAMIC, false);
        }
    }
    ~this()
    {
        if (mMgr)
        {
            mMgr._notifyUniformBufferDestroyed(this);
        }
        if (mShadowBuffer)
        {
            destroy(mShadowBuffer);
        }
    }
    /// Return the manager of this buffer, if any
    ref HardwareBufferManagerBase getManager(){ return mMgr; }
    
    string getName(){ return mName; }
    
}

/** Shared pointer implementation used to share index buffers. */
//alias SharedPtr!HardwareUniformBuffer HardwareUniformBufferPtr;
/*class SharedPtr!HardwareUniformBuffer : SharedPtr!HardwareUniformBuffer
{
public:
    this() { super(); }
    this(HardwareUniformBuffer buf){ super(buf); }
}*/


/** Specialisation of HardwareBuffer for a counter buffer. */
class HardwareCounterBuffer : HardwareBuffer
{
protected:
    HardwareBufferManagerBase mMgr;
    string mName;
    
public:
    /// Should be called by HardwareBufferManager
    this(HardwareBufferManagerBase mgr, size_t sizeBytes, 
         HardwareBuffer.Usage usage, bool useShadowBuffer = false, string name = "")
    {
        super(usage, false, useShadowBuffer);
        mName = name;
        // Calculate the size of the vertices
        mSizeInBytes = sizeBytes;
        
        // Create a shadow buffer if required
        if (mUseShadowBuffer)
        {
            mShadowBuffer = new DefaultHardwareCounterBuffer(mMgr, sizeBytes, HardwareBuffer.Usage.HBU_DYNAMIC, false);
        }
    }
    
    ~this()
    {
        if (mMgr)
        {
            mMgr._notifyCounterBufferDestroyed(this);
        }
        if (mShadowBuffer)
        {
            destroy(mShadowBuffer);
        }
    }
    
    /// Return the manager of this buffer, if any
    HardwareBufferManagerBase getManager() //const 
    { return mMgr; }
    
    string getName() const { return mName; }
}

alias SharedPtr!HardwareCounterBuffer HardwareCounterBufferSharedPtr;
/** Shared pointer implementation used to share counter buffers. */
/*class HardwareCounterBufferSharedPtr : SharedPtr!HardwareCounterBuffer
{
public:
    this(){}
    this(HardwareCounterBuffer buf)
    {
        super(buf);
    }
}*/

/** @} */
/** @} */

/** Locking helper. Guaranteed unlocking even in case of exception.
 * @note Usable in D except when hard segfaults.
 */
struct HardwareBufferLockGuard(T)
{
    this(T p, HardwareBuffer.LockOptions options)
    {
        pBuf = p;
        pData = pBuf.get().lock(options);
    }
    this(T p, size_t offset, size_t length, HardwareBuffer.LockOptions options)
    {
        pBuf = p;
        pData = pBuf.get().lock(offset, length, options);
    }
    ~this()
    {
        pBuf.get().unlock();
    }
    
    T pBuf;
    void* pData;
}