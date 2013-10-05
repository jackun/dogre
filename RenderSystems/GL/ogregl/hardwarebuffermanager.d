module ogregl.hardwarebuffermanager;
import core.sync.mutex;
import std.bitmanip;

import derelict.opengl3.gl;

import ogre.compat;
import ogre.exception;
import ogre.general.root;
import ogre.rendersystem.vertex;
import ogre.rendersystem.hardware;
import ogre.rendersystem.rendersystem;
import ogregl.hardwarevertexbuffer;
import ogregl.hardwareindexbuffer;
import ogregl.rendertovertexbuffer;


// Default threshold at which glMapBuffer becomes more efficient than glBufferSubData (32k?)
enum OGRE_GL_DEFAULT_MAP_BUFFER_THRESHOLD = (1024 * 32);

// Scratch pool management (32 bit structure)
struct GLScratchBufferAlloc
{
    //uint fields;
    //pragma(msg,bitfields!(uint, "size", 31,uint, "free", 1));
    mixin(bitfields!(uint, "size", 31,  /// Size in bytes
                     uint, "free", 1)); /// Free? (pack with size)
}

enum SCRATCH_POOL_SIZE = 1 * 1024 * 1024;
enum SCRATCH_ALIGNMENT = 32;

/** Implementation of HardwareBufferManager for OpenGL. */
class GLHardwareBufferManagerBase : HardwareBufferManagerBase
{
protected:
    ubyte[] mScratchBufferPool;
    Mutex mScratchMutex;
    size_t mMapBufferThreshold;
    
public:
    this()
    {
        mScratchMutex = new Mutex;
        mScratchBufferPool = null;
        mMapBufferThreshold = OGRE_GL_DEFAULT_MAP_BUFFER_THRESHOLD;

        // Init scratch pool
        // TODO make it a configurable size?
        // FIXME 32-bit aligned buffer
        assert(SCRATCH_POOL_SIZE % SCRATCH_ALIGNMENT == 0);
        mScratchBufferPool = new ubyte[SCRATCH_POOL_SIZE];
        GLScratchBufferAlloc* ptrAlloc = cast(GLScratchBufferAlloc*)mScratchBufferPool;
        ptrAlloc.size = SCRATCH_POOL_SIZE - GLScratchBufferAlloc.sizeof;
        ptrAlloc.free = 1;
        
        // non-Win32 machines are having issues glBufferSubData, looks like buffer corruption
        // disable for now until we figure out where the problem lies           
        version(Win32)
        {
            //Nothing
        }
        else
            mMapBufferThreshold = 0;
        
        // Win32 machines with ATI GPU are having issues glMapBuffer, looks like buffer corruption
        // disable for now until we figure out where the problem lies           
        version(Win32)
        if (Root.getSingleton().getRenderSystem().getCapabilities().getVendor() == GPUVendor.GPU_AMD)
        {
            mMapBufferThreshold = 0xffffffffUL  /* maximum unsigned long value */;
        }
        
    }

    ~this()
    {
        destroyAllDeclarations();
        destroyAllBindings();
        destroy(mScratchBufferPool);
        //OGRE_FREE_ALIGN(mScratchBufferPool, MEMCATEGORY_GEOMETRY, SCRATCH_ALIGNMENT);
    }

    /// Creates a vertex buffer
    override SharedPtr!HardwareVertexBuffer createVertexBuffer(size_t vertexSize, 
                                                     size_t numVerts, HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        GLHardwareVertexBuffer buf = 
            new GLHardwareVertexBuffer(this, vertexSize, numVerts, usage, useShadowBuffer);
        {
            synchronized(mVertexBuffersMutex)
                mVertexBuffers ~= buf;
        }
        debug(STDERR) std.stdio.stderr.writeln("GLHardwareBufferManagerBase.createVertexBuffer:", buf);
        return SharedPtr!HardwareVertexBuffer(buf);
    }

    /// Create a hardware vertex buffer
    override SharedPtr!HardwareIndexBuffer createIndexBuffer(
        HardwareIndexBuffer.IndexType itype, size_t numIndexes, 
        HardwareBuffer.Usage usage, bool useShadowBuffer = false)
    {
        GLHardwareIndexBuffer buf = 
            new GLHardwareIndexBuffer(this, itype, numIndexes, usage, useShadowBuffer);
        debug(STDERR) std.stdio.stderr.writeln("GLHardwareBufferManagerBase.createIndexBuffer:", 
                buf, " ", itype, " ", numIndexes, " ", usage, " shdw:", useShadowBuffer);
        {
            synchronized(mIndexBuffersMutex)
                mIndexBuffers ~= buf;
        }
        return SharedPtr!HardwareIndexBuffer(buf);
    }

    /// Create a render to vertex buffer
    override SharedPtr!RenderToVertexBuffer createRenderToVertexBuffer()
    {
        return SharedPtr!RenderToVertexBuffer(new GLRenderToVertexBuffer);
    }

    /// Create a uniform buffer
    override SharedPtr!HardwareUniformBuffer createUniformBuffer(size_t sizeBytes, HardwareBuffer.Usage usage,bool useShadowBuffer, string name = "")
    {
        throw new RenderingApiError(
                    "Uniform buffer not supported in OpenGL RenderSystem.",
                    "GLHardwareBufferManagerBase.createUniformBuffer");
    }

    /// Utility function to get the correct GL usage based on HBU's
    static GLenum getGLUsage(uint usage)
    {
        switch(usage)
        {
            case HardwareBuffer.Usage.HBU_STATIC:
            case HardwareBuffer.Usage.HBU_STATIC_WRITE_ONLY:
                return GL_STATIC_DRAW;
            case HardwareBuffer.Usage.HBU_DYNAMIC:
            case HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY:
                return GL_DYNAMIC_DRAW;
            case HardwareBuffer.Usage.HBU_DYNAMIC_WRITE_ONLY_DISCARDABLE:
                return GL_STREAM_DRAW;
            default:
                return GL_DYNAMIC_DRAW;
        }
    }
    
    /// Utility function to get the correct GL type based on VET's
    static GLenum getGLType(uint type)
    {
        switch(type)
        {
            case VertexElementType.VET_FLOAT1:
            case VertexElementType.VET_FLOAT2:
            case VertexElementType.VET_FLOAT3:
            case VertexElementType.VET_FLOAT4:
                return GL_FLOAT;
            case VertexElementType.VET_SHORT1:
            case VertexElementType.VET_SHORT2:
            case VertexElementType.VET_SHORT3:
            case VertexElementType.VET_SHORT4:
                return GL_SHORT;
            case VertexElementType.VET_COLOUR:
            case VertexElementType.VET_COLOUR_ABGR:
            case VertexElementType.VET_COLOUR_ARGB:
            case VertexElementType.VET_UBYTE4:
                return GL_UNSIGNED_BYTE;
            default:
                return 0;
        }
    }
    
    /** Allocator method to allow us to use a pool of memory as a scratch
            area for hardware buffers. This is because glMapBuffer is incredibly
            inefficient, seemingly no matter what options we give it. So for the
            period of lock/unlock, we will instead allocate a section of a local
            memory pool, and use glBufferSubDataARB / glGetBufferSubDataARB
            instead.
        */
    void* allocateScratch(uint size)
    {
        // simple forward link search based on alloc sizes
        // not that fast but the list should never get that long since not many
        // locks at once (hopefully)
        synchronized(mScratchMutex)
        {    
            
            // Alignment - round up the size to 32 bits
            // control blocks are 32 bits too so this packs nicely
            if (size % 4 != 0)
            {
                size += 4 - (size % 4);
            }
            
            uint bufferPos = 0;
            while (bufferPos < SCRATCH_POOL_SIZE)
            {
                GLScratchBufferAlloc* pNext = cast(GLScratchBufferAlloc*)(mScratchBufferPool.ptr + bufferPos);
                // Big enough?
                if (pNext.free && pNext.size >= size)
                {
                    // split? And enough space for control block
                    if(pNext.size > size + GLScratchBufferAlloc.sizeof)
                    {
                        uint offset = cast(uint)(GLScratchBufferAlloc.sizeof + size);
                        
                        GLScratchBufferAlloc* pSplitAlloc = cast(GLScratchBufferAlloc*)
                            (mScratchBufferPool.ptr + bufferPos + offset);
                        pSplitAlloc.free = 1;
                        // split size is remainder minus new control block
                        pSplitAlloc.size = cast(uint)(pNext.size - size - GLScratchBufferAlloc.sizeof);
                        
                        // New size of current
                        pNext.size = size;
                    }
                    // allocate and return
                    pNext.free = 0;
                    
                    // return pointer just after this control block (++ will do that for us)
                    return ++pNext;
                    
                }
                
                bufferPos += cast(uint)(GLScratchBufferAlloc.sizeof + pNext.size);
                
            }
            
            // no available alloc
            return null;
        }
    }
    
    /// @see allocateScratch
    void deallocateScratch(void* ptr)
    {
        synchronized(mScratchMutex)
        {
            // Simple linear search dealloc
            uint bufferPos = 0;
            GLScratchBufferAlloc* pLast = null;
            while (bufferPos < SCRATCH_POOL_SIZE)
            {
                GLScratchBufferAlloc* pCurrent = cast(GLScratchBufferAlloc*)(mScratchBufferPool.ptr + bufferPos);
                
                // Pointers match?
                if ((mScratchBufferPool.ptr + bufferPos + GLScratchBufferAlloc.sizeof)
                    == ptr)
                {
                    // dealloc
                    pCurrent.free = 1;
                    
                    // merge with previous
                    if (pLast && pLast.free)
                    {
                        // adjust buffer pos
                        bufferPos -= (pLast.size + cast(uint)GLScratchBufferAlloc.sizeof);
                        // merge free space
                        pLast.size = pLast.size + cast(uint)(pCurrent.size + GLScratchBufferAlloc.sizeof);
                        pCurrent = pLast;
                    }
                    
                    // merge with next
                    uint offset = bufferPos + pCurrent.size + cast(uint)GLScratchBufferAlloc.sizeof;
                    if (offset < SCRATCH_POOL_SIZE)
                    {
                        GLScratchBufferAlloc* pNext = cast(GLScratchBufferAlloc*)(
                            mScratchBufferPool.ptr + offset);
                        if (pNext.free)
                        {
                            pCurrent.size = cast(uint)(pCurrent.size + pNext.size + GLScratchBufferAlloc.sizeof);
                        }
                    }
                    
                    // done
                    return;
                }
                
                bufferPos += cast(uint)(GLScratchBufferAlloc.sizeof + pCurrent.size);
                pLast = pCurrent;
                
            }
            
            // Should never get here unless there's a corruption
            assert (false, "Memory deallocation error");
        }
    }
    
    /** Threshold after which glMapBuffer is used and not glBufferSubData
        */
    size_t getGLMapBufferThreshold() const
    {
        return mMapBufferThreshold;
    }

    void setGLMapBufferThreshold( size_t value )
    {
        mMapBufferThreshold = value;
    }
}

/// GLHardwareBufferManagerBase as a Singleton
class GLHardwareBufferManager : HardwareBufferManager
{
public:
    this()
    {
        assert(0, 
               "Don't use GLHardwareBufferManager.ctor directly. This is only for singleton template.\n"
               "Use like HardwareBufferManager.getSingletonInit!(GLHardwareBufferManager)(mGLHardwareBufferManagerBase);\n"
               );
        //super(new GLHardwareBufferManagerBase());
    }
    
    this(HardwareBufferManagerBase imp)
    {
        super(imp);
    }
    
    ~this()
    {
        destroy(mImpl);
    }
    
    /// Utility function to get the correct GL usage based on HBU's
    static GLenum getGLUsage(uint usage) 
    { return GLHardwareBufferManagerBase.getGLUsage(usage); }
    
    /// Utility function to get the correct GL type based on VET's
    static GLenum getGLType(uint type)
    { return GLHardwareBufferManagerBase.getGLType(type); }
    
    /** Allocator method to allow us to use a pool of memory as a scratch
        area for hardware buffers. This is because glMapBuffer is incredibly
        inefficient, seemingly no matter what options we give it. So for the
        period of lock/unlock, we will instead allocate a section of a local
        memory pool, and use glBufferSubDataARB / glGetBufferSubDataARB
        instead.
        */
    void* allocateScratch(uint size)
    {
        return (cast(GLHardwareBufferManagerBase)mImpl).allocateScratch(size);
    }
    
    /// @see allocateScratch
    void deallocateScratch(void* ptr)
    {
        (cast(GLHardwareBufferManagerBase)mImpl).deallocateScratch(ptr);
    }
    
    /** Threshold after which glMapBuffer is used and not glBufferSubData
        */
    size_t getGLMapBufferThreshold() const
    {
        return (cast(GLHardwareBufferManagerBase)mImpl).getGLMapBufferThreshold();
    }
    void setGLMapBufferThreshold( const size_t value )
    {
        (cast(GLHardwareBufferManagerBase)mImpl).setGLMapBufferThreshold(value);
    }
    
}