module ogregl.hardwarevertexbuffer;
import core.stdc.string : memcpy; //can has without?
import derelict.opengl3.gl;

import ogre.rendersystem.hardware;
import ogre.exception;
import ogregl.hardwarebuffermanager;

/// Specialisation of HardwareVertexBuffer for OpenGL
class GLHardwareVertexBuffer : HardwareVertexBuffer 
{
private:
    GLuint mBufferId;
    // Scratch buffer handling
    bool mLockedToScratch;
    size_t mScratchOffset;
    size_t mScratchSize;
    void* mScratchPtr;
    bool mScratchUploadOnUnlock;
    
protected:
    /** See HardwareBuffer. */
    override void* lockImpl(size_t offset, size_t length, LockOptions options)
    {
        if(mIsLocked)
        {
            throw new InternalError(
                        "Invalid attempt to lock an vertex buffer that has already been locked",
                        "GLHardwareVertexBuffer.lock");
        }
        
        debug(STDERR) std.stdio.stderr.writeln("GLHardwareVB.lockImpl");
        void* retPtr = null;
        
        GLHardwareBufferManager glBufManager = cast(GLHardwareBufferManager)(HardwareBufferManager.getSingleton());
        
        // Try to use scratch buffers for smaller buffers
        if( length < glBufManager.getGLMapBufferThreshold() )
        {
            debug(STDERR) std.stdio.stderr.writeln("\tUsing scratch");
            // if this fails, we fall back on mapping
            retPtr = glBufManager.allocateScratch(cast(uint)length);
            
            if (retPtr)
            {
                mLockedToScratch = true;
                mScratchOffset = offset;
                mScratchSize = length;
                mScratchPtr = retPtr;
                mScratchUploadOnUnlock = (options != LockOptions.HBL_READ_ONLY);
                
                if (options != LockOptions.HBL_DISCARD)
                {
                    // have to read back the data before returning the pointer
                    readData(offset, length, retPtr);
                }
            }
        }
        
        if (retPtr is null)
        {
            debug(STDERR) std.stdio.stderr.writeln("\tUsing glBindBuffer");
            GLenum access = 0;
            // Use glMapBuffer
            glBindBuffer( GL_ARRAY_BUFFER, mBufferId );
            // Use glMapBuffer
            if(options == LockOptions.HBL_DISCARD)
            {
                // Discard the buffer
                glBufferData(GL_ARRAY_BUFFER, mSizeInBytes, null, 
                                GLHardwareBufferManager.getGLUsage(mUsage));
                
            }
            if (mUsage & Usage.HBU_WRITE_ONLY)
                access = GL_WRITE_ONLY;
            else if (options == LockOptions.HBL_READ_ONLY)
                access = GL_READ_ONLY;
            else
                access = GL_READ_WRITE;
            
            void* pBuffer = glMapBuffer( GL_ARRAY_BUFFER, access);
            
            if(pBuffer is null)
            {
                throw new InternalError(
                            "Vertex Buffer: Out of memory", "GLHardwareVertexBuffer.lock");
            }
            
            // return offsetted
            retPtr = cast(void*)((cast(ubyte*)pBuffer) + offset);
            debug(STDERR) std.stdio.stderr.writeln("\tbuffer @ ", retPtr, " off: ", offset);
            mLockedToScratch = false;
        }
        mIsLocked = true;
        return retPtr;
    }

    /** See HardwareBuffer. */
    override void unlockImpl()
    {
        if (mLockedToScratch)
        {
            if (mScratchUploadOnUnlock)
            {
                // have to write the data back to vertex buffer
                writeData(mScratchOffset, mScratchSize, mScratchPtr, 
                          mScratchOffset == 0 && mScratchSize == getSizeInBytes());
            }
            
            // deallocate from scratch buffer
            (cast(GLHardwareBufferManager)
                HardwareBufferManager.getSingleton()).deallocateScratch(mScratchPtr);
            
            mLockedToScratch = false;
        }
        else
        {
            
            glBindBuffer(GL_ARRAY_BUFFER, mBufferId);
            
            if(!glUnmapBuffer( GL_ARRAY_BUFFER ))
            {
                throw new InternalError(
                            "Buffer data corrupted, please reload", 
                            "GLHardwareVertexBuffer.unlock");
            }
        }
        
        mIsLocked = false;
    }

public:
    this(HardwareBufferManagerBase mgr, size_t vertexSize, size_t numVertices, 
                           HardwareBuffer.Usage usage, bool useShadowBuffer)

    {
        debug(STDERR) std.stdio.stderr.writeln("GLHardwareVertexBuffer._ctor:", mgr, vertexSize, numVertices, usage, false, useShadowBuffer);
        super(mgr, vertexSize, numVertices, usage, false, useShadowBuffer);
        glGenBuffers( 1, &mBufferId );
        
        if (!mBufferId)
        {
            throw new InternalError(
                        "Cannot create GL vertex buffer", 
                        "GLHardwareVertexBuffer.GLHardwareVertexBuffer");
        }
        
        glBindBuffer(GL_ARRAY_BUFFER, mBufferId);
        
        // Initialise mapped buffer and set usage
        glBufferData(GL_ARRAY_BUFFER, mSizeInBytes, null, 
                        GLHardwareBufferManager.getGLUsage(usage));
        
        debug(STDERR) std.stdio.stderr.writeln("creating vertex buffer = ", mBufferId);
    }

    ~this()
    {
        glDeleteBuffers(1, &mBufferId);
    }

    /** See HardwareBuffer. */
    override void readData(size_t offset, size_t length, void* pDest)
    {
        if(mUseShadowBuffer)
        {
            // get data from the shadow buffer
            void* srcData = mShadowBuffer.lock(offset, length, LockOptions.HBL_READ_ONLY);
            memcpy(pDest, srcData, length);
            mShadowBuffer.unlock();
        }
        else
        {
            // get data from the real buffer
            glBindBuffer(GL_ARRAY_BUFFER, mBufferId);
            
            glGetBufferSubData(GL_ARRAY_BUFFER, offset, length, pDest);
        }
    }

    /** See HardwareBuffer. */
    override void writeData(size_t offset, size_t length,
                   /*const*/ void* pSource, bool discardWholeBuffer = false)
    {
        glBindBuffer(GL_ARRAY_BUFFER, mBufferId);
        
        // Update the shadow buffer
        if(mUseShadowBuffer)
        {
            void* destData = mShadowBuffer.lock(offset, length, 
                                                discardWholeBuffer ? LockOptions.HBL_DISCARD : LockOptions.HBL_NORMAL);
            memcpy(destData, pSource, length);
            mShadowBuffer.unlock();
        }
        
        if (offset == 0 && length == mSizeInBytes)
        {
            glBufferData(GL_ARRAY_BUFFER, mSizeInBytes, pSource, 
                            GLHardwareBufferManager.getGLUsage(mUsage));
        }
        else
        {
            if(discardWholeBuffer)
            {
                glBufferData(GL_ARRAY_BUFFER, mSizeInBytes, null, 
                                GLHardwareBufferManager.getGLUsage(mUsage));
            }
            
            // Now update the real buffer
            glBufferSubData(GL_ARRAY_BUFFER, offset, length, pSource); 
        }
    }

    /** See HardwareBuffer. */
    override void _updateFromShadow()
    {
        if (mUseShadowBuffer && mShadowUpdated && !mSuppressHardwareUpdate)
        {
            debug(STDERR) std.stdio.stderr.writeln("GLHardwareVertexBuffer._updateFromShadow: ", mLockStart, " len:", mLockSize);
            //const
            void *srcData = mShadowBuffer.lock(
                mLockStart, mLockSize, LockOptions.HBL_READ_ONLY);
            
            glBindBuffer(GL_ARRAY_BUFFER, mBufferId);
            debug(STDERR) std.stdio.stderr.writeln("GLHardwareVertexBuffer._updateFromShadow: BufferID:", mBufferId, " from:", srcData);
            
            // Update whole buffer if possible, otherwise normal
            if (mLockStart == 0 && mLockSize == mSizeInBytes)
            {
                glBufferData(GL_ARRAY_BUFFER, mSizeInBytes, srcData,
                                GLHardwareBufferManager.getGLUsage(mUsage));
            }
            else
            {
                glBufferSubData(GL_ARRAY_BUFFER, mLockStart, mLockSize, srcData);
            }
            
            mShadowBuffer.unlock();
            mShadowUpdated = false;
        }
    }
    
    GLuint getGLBufferId() const { return mBufferId; }
}