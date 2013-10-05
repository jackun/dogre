module ogregl.defaulthardwarebuffermanager;
import core.stdc.string : memcpy;
import ogre.rendersystem.hardware;
import ogre.exception;
import ogre.rendersystem.rendersystem;

/// Specialisation of HardwareVertexBuffer for emulation
class GLDefaultHardwareVertexBuffer : HardwareVertexBuffer 
{
protected:
    ubyte[] mData;
    /// @copydoc HardwareBuffer::lock
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return mData.ptr + offset;
    }

    /// @copydoc HardwareBuffer::unlock
    override void unlockImpl()
    {
        // Nothing to do
    }
    
public:
    this(size_t vertexSize, size_t numVertices, HardwareBuffer.Usage usage)
    {
        super(null, vertexSize, numVertices, usage, true, false); // always software, never shadowed
        //mData = static_cast<unsigned char*>(OGRE_MALLOC_SIMD(mSizeInBytes, MEMCATEGORY_GEOMETRY));
        mData = new ubyte[mSizeInBytes]; //TODO simd align?
    }

    this(HardwareBufferManagerBase mgr, size_t vertexSize, size_t numVertices, 
                                  HardwareBuffer.Usage usage)
    {
        super(mgr, vertexSize, numVertices, usage, true, false); // always software, never shadowed
        mData = new ubyte[mSizeInBytes];
    }

    ~this()
    {
        destroy(mData);
    }

    /// @copydoc HardwareBuffer::readData
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }

    /// @copydoc HardwareBuffer::writeData
    
    override void writeData(size_t offset, size_t length, /*const*/ void* pSource,
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
    
    //void* getDataPtr() const { return cast(void*)mData.ptr; }
    void* getDataPtr(size_t offset) const { return cast(void*)(mData.ptr + offset); }
}

/// Specialisation of HardwareIndexBuffer for emulation
class GLDefaultHardwareIndexBuffer : HardwareIndexBuffer
{
protected:
    ubyte[] mData;
    /// @copydoc HardwareBuffer::lock
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        // Only for use internally, no 'locking' as such
        return mData.ptr + offset;
    }

    /// @copydoc HardwareBuffer::unlock
    override void unlockImpl()
    {
        // Nothing to do
    }

public:
    this(IndexType idxType, size_t numIndexes, HardwareBuffer.Usage usage)
    {
        super(null, idxType, numIndexes, usage, true, false); // always software, never shadowed
        mData = new ubyte[mSizeInBytes];
    }

    ~this()
    {
        destroy(mData);
    }

    /// @copydoc HardwareBuffer::readData
    override void readData(size_t offset, size_t length, void* pDest)
    {
        assert((offset + length) <= mSizeInBytes);
        memcpy(pDest, mData.ptr + offset, length);
    }

    /// @copydoc HardwareBuffer::writeData
    override void writeData(size_t offset, size_t length, /*const*/ void* pSource,
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
    
    void* getDataPtr(size_t offset) const { return cast(void*)(mData.ptr + offset); }
}

/** Specialisation of HardwareBufferManager to emulate hardware buffers.
    @remarks
        You might want to instantiate this class if you want to utilise
        classes like MeshSerializer without having initialised the 
        rendering system (which is required to create a 'real' hardware
        buffer manager.
    */
class GLDefaultHardwareBufferManagerBase : HardwareBufferManagerBase
{
    alias HardwareBufferManagerBase._forceReleaseBufferCopies _forceReleaseBufferCopies;
public:
    this() {}
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
        return SharedPtr!HardwareVertexBuffer(
            new GLDefaultHardwareVertexBuffer(this, vertexSize, numVerts, usage));
    }

    /// Create a hardware index buffer
    override SharedPtr!HardwareIndexBuffer 
        createIndexBuffer(HardwareIndexBuffer.IndexType itype, size_t numIndexes, 
                          HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        return SharedPtr!HardwareIndexBuffer(
            new GLDefaultHardwareIndexBuffer(itype, numIndexes, usage) );
    }

    /// Create a render to vertex buffer
    override SharedPtr!RenderToVertexBuffer createRenderToVertexBuffer()
    {
        throw new RenderingApiError(
                    "Cannot create RenderToVertexBuffer in GLDefaultHardwareBufferManagerBase", 
                    "GLDefaultHardwareBufferManagerBase.createRenderToVertexBuffer");
    }
    /// Create a uniform buffer
    override SharedPtr!HardwareUniformBuffer 
        createUniformBuffer(size_t sizeBytes, HardwareBuffer.Usage usage,bool useShadowBuffer, string name = "")
    {
        throw new RenderingApiError(
                    "Cannot create UniformBuffer in GLDefaultHardwareBufferManagerBase", 
                    "GLDefaultHardwareBufferManagerBase.createUniformBuffer");
    }
}

/// GLDefaultHardwareBufferManagerBase as a Singleton
class GLDefaultHardwareBufferManager : HardwareBufferManager
{
public:
    this()
    {
        //FIXME Because how Singleton template is implemented right now
        // proper way probably would be to call HardwareBufferManager.getSingleton(new GLDefaultHardwareBufferManagerBase());
        // Otherwise you get multiple HardwareBufferManagers with different implementations.
        // Subsequent calls to getSingleton() should return HardwareBufferManager with proper implementation.

        //super(new GLDefaultHardwareBufferManagerBase());
        //assert(false, "Initialize with HardwareBufferManager.getSingleton(new GLDefaultHardwareBufferManagerBase());");
        //FIXME Test code
    }

    this(HardwareBufferManagerBase imp)
    {
        super(imp);
    }
    
    ~this()
    {
        destroy(mImpl);
    }
}