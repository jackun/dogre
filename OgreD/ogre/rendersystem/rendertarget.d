module ogre.rendersystem.rendertarget;

//import std.container;
import ogre.compat;
import ogre.config;
import ogre.rendersystem.rendersystem;
import ogre.rendersystem.viewport;
import ogre.scene.camera;
import ogre.rendersystem.rendertargetlistener;
import ogre.image.images;
import ogre.image.pixelformat;
import ogre.general.timer;
import ogre.general.root;
import ogre.general.generals;
import ogre.general.profiler;
import ogre.exception;
import ogre.general.log;

// See ogre.config for these.
/* Define the number of priority groups for the render system's render targets. */
/*#ifndef OGRE_NUM_RENDERTARGET_GROUPS
#define OGRE_NUM_RENDERTARGET_GROUPS 10
#define OGRE_DEFAULT_RT_GROUP 4
#define OGRE_REND_TO_TEX_RT_GROUP 2
#endif*/

/** A 'canvas' which can receive the results of a rendering
    operation.
    @remarks
        This abstract class defines a common root to all targets of rendering operations. A
        render target could be a window on a screen, or another
        offscreen surface like a texture or bump map etc.
    @author
        Steven Streeting
    @version
        1.0
 */
class RenderTarget //: public RenderSysAlloc
{
public:
    enum StatFlags
    {
        SF_NONE           = 0,
        SF_FPS            = 1,
        SF_AVG_FPS        = 2,
        SF_BEST_FPS       = 4,
        SF_WORST_FPS      = 8,
        SF_TRIANGLE_COUNT = 16,
        SF_ALL            = 0xFFFF
    }
    
    struct FrameStats
    {
        float lastFPS;
        float avgFPS;
        float bestFPS;
        float worstFPS;
        ulong bestFrameTime;
        ulong worstFrameTime;
        size_t triangleCount;
        size_t batchCount;
    }
    
    enum FrameBuffer
    {
        FB_FRONT,
        FB_BACK,
        FB_AUTO
    }
    
    this()
    {
        mPriority = OGRE_DEFAULT_RT_GROUP;
        mDepthBufferPoolId = DepthBuffer.PoolId.POOL_DEFAULT;
        mDepthBuffer = null;
        mActive = true;
        mAutoUpdate = true;
        mHwGamma = false;
        mFSAA = 0;
        
        mTimer = Root.getSingleton().getTimer();
        resetStatistics();
    }
    
    ~this()
    {
        // Delete viewports
        foreach (k, vp; mViewportList)
        {
            fireViewportRemoved(vp);
            destroy(vp);
        }
        
        //DepthBuffer keeps track of us, avoid a dangling pointer
        detachDepthBuffer();
        
        
        // Write closing message
        LogManager.getSingleton().stream(LML_TRIVIAL)
            << "Render Target '" << mName << "' "
                << "Average FPS: " << mStats.avgFPS << " "
                << "Best FPS: " << mStats.bestFPS << " "
                << "Worst FPS: " << mStats.worstFPS; 
        
    }
    
    /// Retrieve target's name.
   string getName()
    {
        return mName;
    }
    
    /// Retrieve information about the render target.
    void getMetrics(out uint width, out uint height, out uint colourDepth)
    {
        width = mWidth;
        height = mHeight;
        colourDepth = mColourDepth;
    }
    
    uint getWidth() const
    {
        return mWidth;
    }
    uint getHeight() const
    {
        return mHeight;
    }
    uint getColourDepth() const
    {
        return mColourDepth;
    }
    
    /**
     * Sets the pool ID this RenderTarget should query from. Default value is POOL_DEFAULT.
     * Set to POOL_NO_DEPTH to avoid using a DepthBuffer (or manually controlling it) @see DepthBuffer
     *  @remarks
     *      Changing the pool Id will cause the current depth buffer to be detached unless the old
     *      id and the new one are the same
     */
    void setDepthBufferPool( ushort poolId )
    {
        if( mDepthBufferPoolId != poolId )
        {
            mDepthBufferPoolId = poolId;
            detachDepthBuffer();
        }
    }
    
    //Returns the pool ID this RenderTarget should query from. @see DepthBuffer
    ushort getDepthBufferPool()
    {
        return mDepthBufferPoolId;
    }
    
    ref DepthBuffer getDepthBuffer()
    {
        return mDepthBuffer;
    }
    
    //Returns false if couldn't attach
    bool attachDepthBuffer( DepthBuffer depthBuffer )
    {
        bool retVal = false;
        
        if( (retVal = depthBuffer.isCompatible( this )) == true ) //compiler gets confused
        {
            detachDepthBuffer();
            mDepthBuffer = depthBuffer;
            mDepthBuffer._notifyRenderTargetAttached( this );
        }
        
        return retVal;
    }
    
    void detachDepthBuffer()
    {
        if( mDepthBuffer )
        {
            mDepthBuffer._notifyRenderTargetDetached( this );
            mDepthBuffer = null;
        }
    }
    
    /** Detaches DepthBuffer without notifying it from the detach.
        Useful when called from the DepthBuffer while it iterates through attached
        RenderTargets (@see DepthBuffer::_setPoolId())
    */
    void _detachDepthBuffer()
    {
        mDepthBuffer = null;
    }
    
    /** Tells the target to update it's contents.
        @remarks
            If OGRE is not running in an automatic rendering loop
            (started using Root::startRendering),
            the user of the library is responsible for asking each render
            target to refresh. This is the method used to do this. It automatically
            re-renders the contents of the target using whatever cameras have been
            pointed at it (using Camera::setRenderTarget).
        @par
            This allows OGRE to be used in multi-windowed utilities
            and for contents to be refreshed only when required, rather than
           antly as with the automatic rendering loop.
        @param swapBuffers For targets that support double-buffering, if set 
            to true, the target will immediately
            swap it's buffers after update. Otherwise, the buffers are
            not swapped, and you have to call swapBuffers yourself sometime
            later. You might want to do this on some rendersystems which 
            pause for queued rendering commands to complete before accepting
            swap buffers calls - so you could do other CPU tasks whilst the 
            queued commands complete. Or, you might do this if you want custom
            control over your windows, such as for externally created windows.
    */
    void update(bool _swapBuffers = true)
    {
        mixin(OgreProfileBeginGPUEvent("RenderTarget: \" ~ getName() ~ \""));
        // call implementation
        updateImpl();
        
        if (_swapBuffers)
        {
            // Swap buffers
            swapBuffers(Root.getSingleton().getRenderSystem().getWaitForVerticalBlank());
        }
        mixin(OgreProfileEndGPUEvent("RenderTarget: \" ~ getName() ~ \""));
    }
    
    /** Swaps the frame buffers to display the next frame.
        @remarks
            For targets that are double-buffered so that no
            'in-progress' versions of the scene are displayed
            during rendering. Once rendering has completed (to
            an off-screen version of the window) the buffers
            are swapped to display the new frame.

        @param
            waitForVSync If true, the system waits for the
            next vertical blank period (when the CRT beam turns off
            as it travels from bottom-right to top-left at the
            end of the pass) before flipping. If false, flipping
            occurs no matter what the beam position. Waiting for
            a vertical blank can be slower (and limits the
            framerate to the monitor refresh rate) but results
            in a steadier image with no 'tearing' (a flicker
            resulting from flipping buffers when the beam is
            in the progress of drawing the last frame).
    */
    void swapBuffers(bool waitForVSync = true)
    {  }
    
    /** Adds a viewport to the rendering target.
        @remarks
            A viewport is the rectangle into which rendering output is sent. This method adds
            a viewport to the render target, rendering from the supplied camera. The
            rest of the parameters are only required if you wish to add more than one viewport
            to a single rendering target. Note that size information passed to this method is
            passed as a parametric, i.e. it is relative rather than absolute. This is to allow
            viewports to automatically resize along with the target.
        @param
            cam The camera from which the viewport contents will be rendered (mandatory)
        @param
            ZOrder The relative order of the viewport with others on the target (allows overlapping
            viewports i.e. picture-in-picture). Higher ZOrders are on top of lower ones. The actual number
            is irrelevant, only the relative ZOrder matters (you can leave gaps in the numbering)
        @param
            left The relative position of the left of the viewport on the target, as a value between 0 and 1.
        @param
            top The relative position of the top of the viewport on the target, as a value between 0 and 1.
        @param
            width The relative width of the viewport on the target, as a value between 0 and 1.
        @param
            height The relative height of the viewport on the target, as a value between 0 and 1.
    */
    Viewport addViewport(ref Camera cam, int ZOrder = 0, float left = 0.0f, float top = 0.0f ,
                         float width = 1.0f, float height = 1.0f)
    {       
        // Check no existing viewport with this Z-order
        auto it = ZOrder in mViewportList;
        
        if (it !is null)
        {
            string str = "Can't create another viewport for "
                ~ mName ~ " with Z-Order " ~ std.conv.to!string(ZOrder)
                    ~ " because a viewport exists with this Z-Order already.";
            throw new InvalidParamsError( str, "RenderTarget.addViewport");
        }
        // Add viewport to list
        // Order based on Z-Order
        Viewport vp = new Viewport(cam, this, left, top, width, height, ZOrder);
        
        mViewportList[ZOrder] = vp;
        
        fireViewportAdded(vp);
        
        return vp;
    }
    
    /** Returns the number of viewports attached to this target.*/
    ushort getNumViewports()
    {
        return cast(ushort)mViewportList.length;
        
    }
    
    /** Retrieves a pointer to the viewport with the given index. */
    ref Viewport getViewport(ushort index) //TODO getViewport by index, follow insertion order?
    {
        //assert (index < mViewportList.size() && "Index out of bounds");
        
        return mViewportList[mViewportList.keysAA[index]];
    }
    
    /** Retrieves a pointer to the viewport with the given zorder. 
        @remarks throws if not found.
    */
    ref Viewport getViewportByZOrder(int ZOrder)
    {
        auto i = ZOrder in mViewportList;
        if(i is null)
        {
            throw new ItemNotFoundError("No viewport with given zorder : "
                                        ~ std.conv.to!string(ZOrder), "RenderTarget.getViewportByZOrder");
        }
        return *i;
    }
    
    /** Returns true if and only if a viewport exists at the given ZOrder. */
    bool hasViewportWithZOrder(int ZOrder)
    {
        return (ZOrder in mViewportList) !is null;
    }
    
    /** Removes a viewport at a given ZOrder.
    */
    void removeViewport(int ZOrder)
    {
        auto it = ZOrder in mViewportList;
        
        if (it !is null)
        {
            fireViewportRemoved(*it);
            destroy(*it);
            mViewportList.remove(ZOrder);
        }
    }
    
    /** Removes all viewports on this target.
    */
    void removeAllViewports()
    {
        foreach (k,vp; mViewportList)
        {
            fireViewportRemoved(vp);
            destroy(vp);
        }
        
        mViewportList.clear();
    }
    
    /** Retieves details of current rendering performance.
        @remarks
            If the user application wishes to do it's own performance
            display, or use performance for some other means, this
            method allows it to retrieve the statistics.
            @param
                lastFPS Pointer to a float to receive the number of frames per second (FPS)
                based on the last frame rendered.
            @param
                avgFPS Pointer to a float to receive the FPS rating based on an average of all
                the frames rendered since rendering began (the call to
                Root::startRendering).
            @param
                bestFPS Pointer to a float to receive the best FPS rating that has been achieved
                since rendering began.
            @param
                worstFPS Pointer to a float to receive the worst FPS rating seen so far.
    */
    void getStatistics(out float lastFPS, out float avgFPS,
                       out float bestFPS, out float worstFPS) // Access to stats
    {
        
        // Note - the will have been updated by the last render
        lastFPS = mStats.lastFPS;
        avgFPS = mStats.avgFPS;
        bestFPS = mStats.bestFPS;
        worstFPS = mStats.worstFPS;
    }
    
    FrameStats getStatistics()
    {
        return mStats;
    }
    
    
    /** Gets the number of triangles rendered in the last update() call. */
    size_t getTriangleCount()
    {
        return mStats.triangleCount;
    }
    /** Gets the number of batches rendered in the last update() call. */
    size_t getBatchCount()
    {
        return mStats.batchCount;
    }
    
    /** Individual stats access - gets the number of frames per second (FPS) based on the last frame rendered.
    */
    float getLastFPS()
    {
        return mStats.lastFPS;
    }
    
    /** Individual stats access - gets the average frames per second (FPS) since call to Root::startRendering.
    */
    float getAverageFPS()
    {
        return mStats.avgFPS;
    }
    
    /** Individual stats access - gets the best frames per second (FPS) since call to Root::startRendering.
    */
    float getBestFPS()
    {
        return mStats.bestFPS;
    }
    
    /** Individual stats access - gets the worst frames per second (FPS) since call to Root::startRendering.
    */
    float getWorstFPS()
    {
        return mStats.worstFPS;
    }
    
    /** Individual stats access - gets the best frame time
    */
    float getBestFrameTime()
    {
        return cast(float)mStats.bestFrameTime;
    }
    
    /** Individual stats access - gets the worst frame time
    */
    float getWorstFrameTime()
    {
        return cast(float)mStats.worstFrameTime;
    }
    
    /** Resets saved frame-rate statistices.
    */
    void resetStatistics()
    {
        mStats.avgFPS = 0.0;
        mStats.bestFPS = 0.0;
        mStats.lastFPS = 0.0;
        mStats.worstFPS = 999.0;
        mStats.triangleCount = 0;
        mStats.batchCount = 0;
        mStats.bestFrameTime = 999999;
        mStats.worstFrameTime = 0;
        
        mLastTime = mTimer.getMilliseconds();
        mLastSecond = mLastTime;
        mFrameCount = 0;
    }
    
    /** Gets a custom (maybe platform-specific) attribute.
        @remarks
            This is a nasty way of satisfying any API's need to see platform-specific details.
            It horrid, but D3D needs this kind of info. At least it's abstracted.
        @param
            name The name of the attribute.
        @param
            pData Pointer to memory of the right kind of structure to receive the info.
    */
    void getCustomAttribute(string name, void* pData)
    {
        throw new InvalidParamsError("Attribute not found. " ~ name, " RenderTarget.getCustomAttribute");
    }
    
    /** Add a listener to this RenderTarget which will be called back before & after rendering.
    @remarks
        If you want notifications before and after a target is updated by the system, use
        this method to register your own custom RenderTargetListener class. This is useful
        for potentially adding your own manual rendering commands before and after the
        'normal' system rendering.
    @par NB this should not be used for frame-based scene updates, use Root::addFrameListener for that.
    */
    void addListener(RenderTargetListener listener)
    {
        //if(mListeners[].find(listener).empty)//TODO Check if listener already added?
        mListeners.insert(listener);
    }
    /** Removes a RenderTargetListener previously registered using addListener. */
    void removeListener(RenderTargetListener listener)
    {
        mListeners.removeFromArray(listener);
    }
    /** Removes all listeners from this instance. */
    void removeAllListeners()
    {
        mListeners.clear();
    }
    
    /** Sets the priority of this render target in relation to the others. 
    @remarks
        This can be used in order to schedule render target updates. Lower
        priorities will be rendered first. Note that the priority must be set
        at the time the render target is attached to the render system, changes
        afterwards will not affect the ordering.
    */
    void setPriority( ubyte priority ) { mPriority = priority; }
    /** Gets the priority of a render target. */
    ubyte getPriority(){ return mPriority; }
    
    /** Used to retrieve or set the active state of the render target.
    */
    bool isActive()
    {
        return mActive;
    }
    
    /** Used to set the active state of the render target.
    */
    void setActive( bool state )
    {
        mActive = state;
    }
    
    /** Sets whether this target should be automatically updated if Ogre's rendering
        loop or Root::_updateAllRenderTargets is being used.
    @remarks
        By default, if you use Ogre's own rendering loop (Root::startRendering)
        or call Root::_updateAllRenderTargets, all render targets are updated 
        automatically. This method allows you to control that behaviour, if 
        for example you have a render target which you only want to update periodically.
    @param autoupdate If true, the render target is updated during the automatic render
        loop or when Root::_updateAllRenderTargets is called. If false, the 
        target is only updated when its update() method is called explicitly.
    */
    void setAutoUpdated(bool autoupdate)
    {
        mAutoUpdate = autoupdate;
    }
    /** Gets whether this target is automatically updated if Ogre's rendering
        loop or Root::_updateAllRenderTargets is being used.
    */
    bool isAutoUpdated()
    {
        return mAutoUpdate;
    }
    
    /** Copies the current contents of the render target to a pixelbox. 
    @remarks See suggestPixelFormat for a tip as to the best pixel format to
        extract into, although you can use whatever format you like and the 
        results will be converted.
    */
    abstract void copyContentsToMemory(PixelBox dst, FrameBuffer buffer = FrameBuffer.FB_AUTO);
    
    /** Suggests a pixel format to use for extracting the data in this target, 
        when calling copyContentsToMemory.
    */
    PixelFormat suggestPixelFormat(){ return PixelFormat.PF_BYTE_RGBA; }
    
    /** Writes the current contents of the render target to the named file. */
    void writeContentsToFile(string filename)
    {
        PixelFormat pf = suggestPixelFormat();
        
        ubyte[] data = new ubyte[mWidth * mHeight * PixelUtil.getNumElemBytes(pf)];
        void *pData = cast(void*) data.ptr;
        
        PixelBox pb = new PixelBox(mWidth, mHeight, 1, pf, pData);
        
        copyContentsToMemory(pb);
        
        (new Image()).loadDynamicImage(data, mWidth, mHeight, 1, pf, false, 1, 0).save(filename);
        
        destroy(data);//TODO Or let GC deal with it
    }
    
    /** Writes the current contents of the render target to the (PREFIX)(time-stamp)(SUFFIX) file.
        @return the name of the file used.*/
    //TODO writeContentsToTimestampedFile
    string writeContentsToTimestampedFile(string filenamePrefix,string filenameSuffix)
    {
        assert(false, "Not implemented yet.");
        /*struct tm *pTime;
        time_t ctTime; time(&ctTime);
        pTime = localtime( &ctTime );
        Ogre::StringStream oss;
        oss << std::setw(2) << std::setfill('0') << (pTime.tm_mon + 1)
            << std::setw(2) << std::setfill('0') << pTime.tm_mday
                << std::setw(2) << std::setfill('0') << (pTime.tm_year + 1900)
                << "_" << std::setw(2) << std::setfill('0') << pTime.tm_hour
                << std::setw(2) << std::setfill('0') << pTime.tm_min
                << std::setw(2) << std::setfill('0') << pTime.tm_sec
                << std::setw(3) << std::setfill('0') << (mTimer.getMilliseconds() % 1000);
        String filename = filenamePrefix + oss.str() + filenameSuffix;
        writeContentsToFile(filename);
        return filename;*/
        
    }
    
    abstract bool requiresTextureFlipping();
    
    /** Utility method to notify a render target that a camera has been removed,
    incase it was ref erring to it as a viewer.
    */
    void _notifyCameraRemoved(Camera cam)
    {
        foreach (k,vp; mViewportList)
        {
            if (vp.getCamera() == cam)
            {
                // disable camera link
                vp.setCamera(null);
            }
        }
    }
    
    /** Indicates whether this target is the primary window. The
        primary window is special in that it is destroyed when
        ogre is shut down, and cannot be destroyed directly.
        This is the case because it holds the context for vertex,
        index buffers and textures.
    */
    bool isPrimary()
    {
        // RenderWindow will override and return true for the primary window
        return false;
    }
    
    /** Indicates whether on rendering, linear colour space is converted to 
        sRGB gamma colour space. This is the exact opposite conversion of
        what is indicated by Texture::isHardwareGammaEnabled, and can only
        be enabled on creation of the render target. For render windows, it's
        enabled through the 'gamma' creation misc parameter. For textures, 
        it is enabled through the hwGamma parameter to the create call.
    */
    bool isHardwareGammaEnabled(){ return mHwGamma; }
    
    /** Indicates whether multisampling is performed on rendering and at what level.
    */
    uint getFSAA() const { return mFSAA; }
    
    /** Gets the FSAA hint (@see Root::createRenderWindow)
    */
   string getFSAAHint(){ return mFSAAHint; }
    
    /** RenderSystem specific interface for a RenderTarget;
        this should be subclassed by RenderSystems.
    */
    interface Impl
    {
    }
    /** Get rendersystem specific interface for this RenderTarget.
        This is used by the RenderSystem to (un)bind this target, 
        and to get specific information like surfaces
        and framebuffer objects.
    */
    Impl _getImpl()
    {
        return null;
    }
    
    /** Method for manual management of rendering : fires 'preRenderTargetUpdate'
        and initialises statistics etc.
    @remarks 
    <ul>
    <li>_beginUpdate resets statistics and fires 'preRenderTargetUpdate'.</li>
    <li>_updateViewport renders the given viewport (even if it is not autoupdated),
    fires preViewportUpdate and postViewportUpdate and manages statistics.</li>
    <li>_updateAutoUpdatedViewports renders only viewports that are auto updated,
    fires preViewportUpdate and postViewportUpdate and manages statistics.</li>
    <li>_endUpdate() ends statistics calculation and fires postRenderTargetUpdate.</li>
    </ul>
    you can use it like this for example :
    <pre>
        renderTarget._beginUpdate();
        renderTarget._updateViewport(1); // which is not auto updated
        renderTarget._updateViewport(2); // which is not auto updated
        renderTarget._updateAutoUpdatedViewports();
        renderTarget._endUpdate();
        renderTarget.swapBuffers(true);
    </pre>
        Please note that in that case, the zorder may not work as you expect,
        since you are responsible for calling _updateViewport in the correct order.
    */
    void _beginUpdate()
    {
        // notify listeners (pre)
        firePreUpdate();
        
        mStats.triangleCount = 0;
        mStats.batchCount = 0;
    }
    
    /** Method for manual management of rendering - renders the given 
    viewport (even if it is not autoupdated)
    @remarks
    This also fires preViewportUpdate and postViewportUpdate, and manages statistics.
    You should call it between _beginUpdate() and _endUpdate().
    @see _beginUpdate for more details.
    @param zorder The zorder of the viewport to update.
    @param updateStatistics Whether you want to update statistics or not.
    */
    void _updateViewport(int zorder, bool updateStatistics = true)
    {
        auto it = zorder in mViewportList;
        if (it !is null)
        {
            _updateViewport(*it, updateStatistics);
        }
        else
        {
            throw new ItemNotFoundError("No viewport with given zorder : "
                                        ~ std.conv.to!string(zorder), "RenderTarget._updateViewport");
        }
    }
    
    /** Method for manual management of rendering - renders the given viewport (even if it is not autoupdated)
    @remarks
    This also fires preViewportUpdate and postViewportUpdate, and manages statistics
    if needed. You should call it between _beginUpdate() and _endUpdate().
    @see _beginUpdate for more details.
    @param viewport The viewport you want to update, it must be bound to the rendertarget.
    @param updateStatistics Whether you want to update statistics or not.
    */
    void _updateViewport(ref Viewport viewport, bool updateStatistics = true)
    {
        assert(viewport.getTarget() == this ,
               "RenderTarget._updateViewport the requested viewport is " ~
               "not bound to the rendertarget!");
        
        fireViewportPreUpdate(viewport);
        viewport.update();
        if(updateStatistics)
        {
            mStats.triangleCount += viewport._getNumRenderedFaces();
            mStats.batchCount += viewport._getNumRenderedBatches();
        }
        fireViewportPostUpdate(viewport);
    }
    
    /** Method for manual management of rendering - renders only viewports that are auto updated
    @remarks
    This also fires preViewportUpdate and postViewportUpdate, and manages statistics.
    You should call it between _beginUpdate() and _endUpdate().
    See _beginUpdate for more details.
    @param updateStatistics Whether you want to update statistics or not.
    @see _beginUpdate()
    */
    void _updateAutoUpdatedViewports(bool updateStatistics = true)
    {
        // Go through viewports in Z-order
        // Tell each to refresh
        auto keys = std.algorithm.sort(mViewportList.keys);
        foreach(k; keys)
        {
            auto vp = mViewportList[k];
            if(vp.isAutoUpdated())
            {
                _updateViewport(vp, updateStatistics);
            }
        }
    }
    
    /** Method for manual management of rendering - finishes statistics calculation 
        and fires 'postRenderTargetUpdate'.
    @remarks
    You should call it after a _beginUpdate
    @see _beginUpdate for more details.
    */
    void _endUpdate()
    {
        // notify listeners (post)
        firePostUpdate();
        
        // Update statistics (always on top)
        updateStats();
    }
    
protected:
    /// The name of this target.
    string mName;
    /// The priority of the render target.
    ubyte mPriority;
    
    uint mWidth;
    uint mHeight;
    uint mColourDepth;
    ushort      mDepthBufferPoolId;
    DepthBuffer mDepthBuffer;
    
    // Stats
    FrameStats mStats;
    
    Timer mTimer;
    ulong mLastSecond;
    ulong mLastTime;
    size_t mFrameCount;
    
    bool mActive;
    bool mAutoUpdate;
    // Hardware sRGB gamma conversion done on write?
    bool mHwGamma;
    // FSAA performed?
    uint mFSAA;
    string mFSAAHint;
    
    void updateStats()
    {
        ++mFrameCount;
        ulong thisTime = mTimer.getMilliseconds();
        
        // check frame time
        ulong frameTime = thisTime - mLastTime ;
        mLastTime = thisTime ;
        
        mStats.bestFrameTime = std.algorithm.min(mStats.bestFrameTime, frameTime);
        mStats.worstFrameTime = std.algorithm.max(mStats.worstFrameTime, frameTime);
        
        // check if new second (update only once per second)
        if (thisTime - mLastSecond > 1000) 
        { 
            // new second - not 100% precise
            mStats.lastFPS = cast(float)mFrameCount / cast(float)(thisTime - mLastSecond) * 1000.0f;
            
            if (mStats.avgFPS == 0)
                mStats.avgFPS = mStats.lastFPS;
            else
                mStats.avgFPS = (mStats.avgFPS + mStats.lastFPS) / 2; // not strictly correct, but good enough
            
            mStats.bestFPS = std.algorithm.max(mStats.bestFPS, mStats.lastFPS);
            mStats.worstFPS = std.algorithm.min(mStats.worstFPS, mStats.lastFPS);
            
            mLastSecond = thisTime ;
            mFrameCount  = 0;
            
        }
        
    }
    
    //typedef map<int, Viewport*>::type ViewportList;
    alias Viewport[int] ViewportList;
    /// List of viewports, map on Z-order
    ViewportList mViewportList;
    
    //typedef vector<RenderTargetListener*>::type RenderTargetListenerList;
    alias RenderTargetListener[] RenderTargetListenerList;
    RenderTargetListenerList mListeners;
    
    
    /// internal method for firing events
    void firePreUpdate()
    {
        RenderTargetEvent evt;
        evt.source = this;
        
        foreach(l; mListeners)
        {
            l.preRenderTargetUpdate(evt);
        }
    }
    /// internal method for firing events
    void firePostUpdate()
    {
        RenderTargetEvent evt;
        evt.source = this;
        
        foreach(l; mListeners)
        {
            l.postRenderTargetUpdate(evt);
        }
    }
    /// internal method for firing events
    void fireViewportPreUpdate(ref Viewport vp)
    {
        RenderTargetViewportEvent evt;
        evt.source = vp;
        
        foreach(l; mListeners)
        {
            l.preViewportUpdate(evt);
        }
    }
    /// internal method for firing events
    void fireViewportPostUpdate(ref Viewport vp)
    {
        RenderTargetViewportEvent evt;
        evt.source = vp;
        
        foreach(l; mListeners)
        {
            l.postViewportUpdate(evt);
        }
    }
    /// internal method for firing events
    void fireViewportAdded(ref Viewport vp)
    {
        RenderTargetViewportEvent evt;
        evt.source = vp;
        
        foreach(l; mListeners)
        {
            l.viewportAdded(evt);
        }
    }
    /// internal method for firing events
    void fireViewportRemoved(ref Viewport vp)
    {
        RenderTargetViewportEvent evt;
        evt.source = vp;
        
        // Make a temp copy of the listeners
        // some will want to remove themselves as listeners when they get this
        RenderTargetListenerList tmp = mListeners.dup;
        foreach(l; tmp)
        {
            l.viewportRemoved(evt);
        }
    }
    
    /// Internal implementation of update()
    void updateImpl()
    {
        _beginUpdate();
        _updateAutoUpdatedViewports(true);
        _endUpdate();
    }
}
