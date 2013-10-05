module ogre.rendersystem.rendertexture;

//import std.container;

import ogre.rendersystem.rendertarget;
import ogre.rendersystem.hardware;
import ogre.image.pixelformat;
import ogre.image.images;
import ogre.exception;
import ogre.compat;
import ogre.config;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup RenderSystem
    *  @{
    */
/** This class represents a RenderTarget that renders to a Texture. There is no 1 on 1
        relation between Textures and RenderTextures, as there can be multiple 
        RenderTargets rendering to different mipmaps, faces (for cubemaps) or slices (for 3D textures)
        of the same Texture.
    */
class RenderTexture: RenderTarget
{
public:
    this(HardwarePixelBuffer buffer, size_t zoffset)
    {
        mBuffer = buffer;
        mZOffset = zoffset;

        mPriority = OGRE_REND_TO_TEX_RT_GROUP;
        mWidth = cast(uint)mBuffer.getWidth();
        mHeight = cast(uint)mBuffer.getHeight();
        mColourDepth = cast(uint)PixelUtil.getNumElemBits(mBuffer.getFormat());
    }
    ~this()
    {
        mBuffer._clearSliceRTT(0);
    }
    
    override void copyContentsToMemory(PixelBox dst, FrameBuffer buffer)
    {
        if (buffer == FrameBuffer.FB_AUTO) buffer = FrameBuffer.FB_FRONT;
        if (buffer != FrameBuffer.FB_FRONT)
        {
            throw new InvalidParamsError(
                        "Invalid buffer.",
                        "RenderTexture.copyContentsToMemory" );
        }
        
        mBuffer.blitToMemory(dst);
    }

    override PixelFormat suggestPixelFormat()
    {
        return mBuffer.getFormat();
    }
    
protected:
    HardwarePixelBuffer mBuffer;
    size_t mZOffset;
}

/** This class represents a render target that renders to multiple RenderTextures
        at once. Surfaces can be bound and unbound at will, as long as the followingraints
        are met:
        - All bound surfaces have the same size
        - All bound surfaces have the same bit depth
        - Target 0 is bound
    */
class MultiRenderTarget: RenderTarget
{
public:
    this(string name)
    {
        mPriority = OGRE_REND_TO_TEX_RT_GROUP;
        mName = name;
        /// Width and height is unknown with no targets attached
        mWidth = mHeight = 0;
    }
    
    /** Bind a surface to a certain attachment point.
            @param attachment   0 .. mCapabilities.getNumMultiRenderTargets()-1
            @param target       RenderTexture to bind.

            It does not bind the surface and fails with an exception (ERR_INVALIDPARAMS) if:
            - Not all bound surfaces have the same size
            - Not all bound surfaces have the same internal format 
        */
    
    void bindSurface(size_t attachment, ref RenderTexture target)
    {
        for (size_t i = mBoundSurfaces.length; i <= attachment; ++i)
        {
            mBoundSurfaces.insert(null); //TODO .insert(null)
        }
        mBoundSurfaces[attachment] = target;
        
        bindSurfaceImpl(attachment, target);
    }
    
    
    
    /** Unbind attachment.
        */
    
    void unbindSurface(size_t attachment)
    {
        if (attachment < mBoundSurfaces.length)
            mBoundSurfaces[attachment] = null;
        unbindSurfaceImpl(attachment);
    }
    
    /** Error throwing implementation, it's not possible to write a MultiRenderTarget
            to disk. 
        */
    override void copyContentsToMemory(PixelBox dst, FrameBuffer buffer)
    {
        throw new InvalidParamsError(
                    "Cannot get MultiRenderTargets pixels",
                    "MultiRenderTarget.copyContentsToMemory");
    }
    
    /// Irrelevant implementation since cannot copy
    override PixelFormat suggestPixelFormat(){ return PixelFormat.PF_UNKNOWN; }
    
    //typedef vector<RenderTexture*>::type BoundSufaceList;
    alias RenderTexture[] BoundSufaceList;
    /// Get a list of the surfaces which have been bound
    ref BoundSufaceList getBoundSurfaceList(){ return mBoundSurfaces; }
    
    /** Get a pointer to a bound surface */
    ref RenderTexture getBoundSurface(size_t index)
    {
        //assert (index < mBoundSurfaces.length);
        return mBoundSurfaces[index];
    }
    
    
protected:
    BoundSufaceList mBoundSurfaces;

    // Implemented in render systems
    /// implementation of bindSurface, must be provided
    abstract void bindSurfaceImpl(size_t attachment, RenderTexture target);
    /// implementation of unbindSurface, must be provided
    abstract void unbindSurfaceImpl(size_t attachment);
}
/** @} */
/** @} */