module ogre.rendersystem.viewport;

import std.algorithm;
//import std.container;

import ogre.scene.camera;
import ogre.compat;
import ogre.config;
import ogre.general.colourvalue;
import ogre.general.common;
import ogre.math.frustum;
import ogre.math.vector;
import ogre.materials.materialmanager;
import ogre.general.root;
import ogre.rendersystem.rendertarget;
import ogre.rendersystem.renderqueue;
import ogre.rendersystem.rendersystem;
import ogre.exception;

/** An abstraction of a viewport, i.e. a rendering region on a render
    target.
    @remarks
        A viewport is the meeting of a camera and a rendering surface -
        the camera renders the scene from a viewpoint, and places its
        results into some subset of a rendering target, which may be the
        whole surface or just a part of the surface. Each viewport has a
        single camera as source and a single target as destination. A
        camera only has 1 viewport, but a render target may have several.
        A viewport also has a Z-order, i.e. if there is more than one
        viewport on a single render target and they overlap, one must
        obscure the other in some predetermined way.
*/
class Viewport //: public ViewportAlloc
{
public:
    /** Listener interface so you can be notified of Viewport changes. */
    interface Listener
    {
        /** Notification of when a new camera is set to target listening Viewport. */
        void viewportCameraChanged(Viewport viewport);
        
        /** Notification of when target listening Viewport's dimensions changed. */
        void viewportDimensionsChanged(Viewport viewport);
        
        /** Notification of when target listening Viewport's is destroyed. */
        void viewportDestroyed(Viewport viewport);
    }
    
    /** The usual constructor.
        @param camera
            Pointer to a camera to be the source for the image.
        @param target
            Pointer to the render target to be the destination
            for the rendering.
        @param left, top, width, height
            Dimensions of the viewport, expressed as a value between
            0 and 1. This allows the dimensions to apply irrespective of
            changes in the target's size: e.g. to fill the whole area,
            values of 0,0,1,1 are appropriate.
        @param ZOrder
            Relative Z-order on the target. Lower = further to
            the front.
    */
    this(
        ref Camera camera,
        ref RenderTarget target,
        Real left, Real top,
        Real width, Real height,
        int ZOrder)
    {           
        mCamera = camera;
        mTarget = target;
        mRelLeft = left;
        mRelTop = top;
        mRelWidth = width;
        mRelHeight = height;
        // Actual dimensions will update later
        mZOrder = ZOrder;
        mBackColour = ColourValue.Black;
        mDepthClearValue = 1;
        mClearEveryFrame = true;
        mClearBuffers = FrameBufferType.FBT_COLOUR | FrameBufferType.FBT_DEPTH;
        mUpdated = false;
        mShowOverlays = true;
        mShowSkies = true;
        mShowShadows = true;
        mVisibilityMask = 0xFFFFFFFF;
        mRQSequence = null;
        mMaterialSchemeName = MaterialManager.DEFAULT_SCHEME_NAME;
        mIsAutoUpdated = true;
        
        /*#if OGRE_COMPILER != OGRE_COMPILER_GCCE && OGRE_PLATFORM != OGRE_PLATFORM_ANDROID
    LogManager::getSingleton().stream(LML_TRIVIAL)
            << "Creating viewport on target '" << target.getName() << "'"
                << ", rendering from camera '" << (cam != 0 ? cam.getName() : "NULL") << "'"
                << ", relative dimensions " << std::ios::fixed << std::setprecision(2) 
                << "L: " << left << " T: " << top << " W: " << width << " H: " << height
                << " ZOrder: " << ZOrder;
#endif*/
        
        // Set the default orientation mode
        mOrientationMode = mDefaultOrientationMode;
        
        // Set the default material scheme
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        mMaterialSchemeName = rs._getDefaultViewportMaterialScheme();
        
        // Calculate actual dimensions
        _updateDimensions();
        
        // notify camera
        if(camera) camera._notifyViewport(this);
    }
    
    /** Default destructor.
    */
    ~this()
    {
        // some will want to remove themselves as listeners when they get this
        ListenerList tmp;
        std.algorithm.swap(mListeners, tmp);
        //for (ListenerList::iterator i = listenersCopy.begin(); i != listenersCopy.end(); ++i)
        foreach (l; tmp)
        {
            l.viewportDestroyed(this);
        }
        
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        if ((rs) && (rs._getViewport() == this))
        {
            rs._setViewport(null);
        }
    }
    
    /** Notifies the viewport of a possible change in dimensions.
        @remarks
            Used by the target to update the viewport's dimensions
            (usually the result of a change in target size).
        @note
            Internal use by Ogre only.
    */
    void _updateDimensions()
    {
        Real height = cast(Real) mTarget.getHeight();
        Real width = cast(Real) mTarget.getWidth();
        
        mActLeft = cast(int) (mRelLeft * width);
        mActTop = cast(int) (mRelTop * height);
        mActWidth = cast(int) (mRelWidth * width);
        mActHeight = cast(int) (mRelHeight * height);
        
        // This will check if the cameras getAutoAspectRatio() property is set.
        // If it's true its aspect ratio is fit to the current viewport
        // If it's false the camera remains unchanged.
        // This allows cameras to be used to render to many viewports,
        // which can have their own dimensions and aspect ratios.
        
        if (mCamera) 
        {
            if (mCamera.getAutoAspectRatio())
                mCamera.setAspectRatio(cast(Real) mActWidth / cast(Real) mActHeight);
            
            static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            {
                //Do nothing
            }
            else
                mCamera.setOrientationMode(mOrientationMode);
        }
        
        /*#if OGRE_COMPILER != OGRE_COMPILER_GCCE
    LogManager::getSingleton().stream(LML_TRIVIAL)
            << "Viewport for camera '" << (mCamera != 0 ? mCamera.getName() : "NULL") << "'"
                << ", actual dimensions "   << std::ios::fixed << std::setprecision(2) 
                << "L: " << mActLeft << " T: " << mActTop << " W: " << mActWidth << " H: " << mActHeight;
#endif*/
        
        mUpdated = true;
        
        foreach (l; mListeners)
        {
            l.viewportDimensionsChanged(this);
        }
    }
    
    /** Instructs the viewport to updates its contents.
    */
    void update()
    {
        if (mCamera)
        {
            // Tell Camera to render into me
            mCamera._renderScene(this, mShowOverlays);
        }
    }
    
    /** Instructs the viewport to clear itself, without performing an update.
     @remarks
        You would not normally call this method when updating the viewport, 
        since the viewport usually clears itself when updating anyway (@see 
        Viewport::setClearEveryFrame). However, if you wish you have the
        option of manually clearing the frame buffer (or elements of it)
        using this method.
     @param buffers Bitmask identifying which buffer elements to clear
     @param colour The colour value to clear to, if FBT_COLOUR is included
     @param depth The depth value to clear to, if FBT_DEPTH is included
     @param stencil The stencil value to clear to, if FBT_STENCIL is included
    */
    void clear(uint buffers = FrameBufferType.FBT_COLOUR | FrameBufferType.FBT_DEPTH,
              ColourValue colour = ColourValue.Black, 
               Real depth = 1.0f, ushort stencil = 0)
    {
        RenderSystem rs = Root.getSingleton().getRenderSystem();
        if (rs)
        {
            Viewport currentvp = rs._getViewport();
            if (currentvp && currentvp == this)
                rs.clearFrameBuffer(buffers, colour, depth, stencil);
            else if (currentvp)
            {
                rs._setViewport(this);
                rs.clearFrameBuffer(buffers, colour, depth, stencil);
                rs._setViewport(currentvp);
            }
        }
    }
    
    /** Retrieves a pointer to the render target for this viewport.
    */
    ref RenderTarget getTarget()
    {
        return mTarget;
    }
    
    /** Retrieves a pointer to the camera for this viewport.
    */
    ref Camera getCamera()
    {
        return mCamera;
    }
    
    /** Sets the camera to use for rendering to this viewport. */
    void setCamera(Camera cam)
    {
        if(mCamera)
        {
            if(mCamera.getViewport() == this)
            {
                mCamera._notifyViewport(null);
            }
        }
        
        mCamera = cam;
        if (cam)
        {
            // update aspect ratio of new camera if needed.
            if (cam.getAutoAspectRatio())
            {
                cam.setAspectRatio(cast(Real) mActWidth / cast(Real) mActHeight);
            }
            
            static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            {
                //Do nothing
            }
            else
                cam.setOrientationMode(mOrientationMode);
            
            cam._notifyViewport(this);
        }
        
        foreach (l; mListeners)
        {
            l.viewportCameraChanged(this);
        }
    }
    
    /** Gets the Z-Order of this viewport. */
    int getZOrder()
    {
        return mZOrder;
    }
    /** Gets one of the relative dimensions of the viewport,
        a value between 0.0 and 1.0.
    */
    Real getLeft()
    {
        return mRelLeft;
    }
    
    /** Gets one of the relative dimensions of the viewport, a value
        between 0.0 and 1.0.
    */
    Real getTop()
    {
        return mRelTop;
    }
    
    /** Gets one of the relative dimensions of the viewport, a value
        between 0.0 and 1.0.
    */
    
    Real getWidth()
    {
        return mRelWidth;
    }
    /** Gets one of the relative dimensions of the viewport, a value
        between 0.0 and 1.0.
    */
    
    Real getHeight()
    {
        return mRelHeight;
    }
    /** Gets one of the actual dimensions of the viewport, a value in
        pixels.
    */
    
    int getActualLeft()
    {
        return mActLeft;
    }
    /** Gets one of the actual dimensions of the viewport, a value in
        pixels.
    */
    
    int getActualTop()
    {
        return mActTop;
    }
    /** Gets one of the actual dimensions of the viewport, a value in
        pixels.
    */
    int getActualWidth()
    {
        return mActWidth;
    }
    /** Gets one of the actual dimensions of the viewport, a value in
        pixels.
    */
    
    int getActualHeight()
    {
        return mActHeight;
    }
    
    /** Sets the dimensions (after creation).
        @param
            left
        @param
            top
        @param
            width
        @param
            height Dimensions relative to the size of the target,
            represented as real values between 0 and 1. i.e. the full
            target area is 0, 0, 1, 1.
    */
    void setDimensions(Real left, Real top, Real width, Real height)
    {
        mRelLeft = left;
        mRelTop = top;
        mRelWidth = width;
        mRelHeight = height;
        _updateDimensions();
    }
    
    /** Set the orientation mode of the viewport.
    */
    void setOrientationMode(OrientationMode orientationMode, bool setDefault = true)
    {
        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            throw new NotImplementedError(
                "Setting Viewport orientation mode is not supported",
                /*__FUNCTION__*/ "Viewport.setOrientationMode");
        
        mOrientationMode = orientationMode;
        
        if (setDefault)
        {
            setDefaultOrientationMode(orientationMode);
        }
        
        if (mCamera)
        {
            mCamera.setOrientationMode(mOrientationMode);
        }
        
        // Update the render system config
        /*#if OGRE_PLATFORM == OGRE_PLATFORM_APPLE_IOS
        RenderSystem* rs = Root::getSingleton().getRenderSystem();
        if(mOrientationMode == OR_LANDSCAPELEFT)
            rs.setConfigOption("Orientation", "Landscape Left");
        else if(mOrientationMode == OR_LANDSCAPERIGHT)
            rs.setConfigOption("Orientation", "Landscape Right");
        else if(mOrientationMode == OR_PORTRAIT)
            rs.setConfigOption("Orientation", "Portrait");
#endif*/
    }
    
    /** Get the orientation mode of the viewport.
    */
    OrientationMode getOrientationMode()
    {
        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            throw new NotImplementedError(
                "Getting Viewport orientation mode is not supported",
                /*__FUNCTION__*/ "Viewport.getOrientationMode");
        return mOrientationMode;
    }
    
    /** Set the initial orientation mode of viewports.
    */
    static void setDefaultOrientationMode(OrientationMode orientationMode)
    {
        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            throw new NotImplementedError(
                "Setting default Viewport orientation mode is not supported",
                /*__FUNCTION__*/ "Viewport.setDefaultOrientationMode");
        mDefaultOrientationMode = orientationMode;
    }
    
    /** Get the initial orientation mode of viewports.
    */
    static OrientationMode getDefaultOrientationMode()
    {
        static if(OGRE_NO_VIEWPORT_ORIENTATIONMODE)
            throw new NotImplementedError(
                "Getting default Viewport orientation mode is not supported",
                /*__FUNCTION__*/ "Viewport.getDefaultOrientationMode");
        return mDefaultOrientationMode;
    }
    
    /** Sets the initial background colour of the viewport (before
        rendering).
    */
    void setBackgroundColour(ColourValue colour)
    {
        mBackColour = colour;
    }
    
    /** Gets the background colour.
    */
   ColourValue getBackgroundColour()
    {
        return mBackColour;
    }
    
    /** Sets the initial depth buffer value of the viewport (before
        rendering). Default is 1
    */
    void setDepthClear( Real depth )
    {
        mDepthClearValue = depth;
    }
    
    /** Gets the default depth buffer value to which the viewport is cleared.
    */
    Real getDepthClear()
    {
        return mDepthClearValue;
    }
    
    /** Determines whether to clear the viewport before rendering.
    @remarks
        You can use this method to set which buffers are cleared
        (if any) before rendering every frame.
    @param clear Whether or not to clear any buffers
    @param buffers One or more values from FrameBufferType denoting
        which buffers to clear, if clear is set to true. Note you should
        not clear the stencil buffer here unless you know what you're doing.
     */
    void setClearEveryFrame(bool clear, uint buffers = FrameBufferType.FBT_COLOUR | FrameBufferType.FBT_DEPTH)
    {
        mClearEveryFrame = clear;
        mClearBuffers = buffers;
    }
    
    /** Determines if the viewport is cleared before every frame.
    */
    bool getClearEveryFrame()
    {
        return mClearEveryFrame;
    }
    
    /** Gets which buffers are to be cleared each frame. */
    uint getClearBuffers()
    {
        return mClearBuffers;
    }
    
    /** Sets whether this viewport should be automatically updated 
        if Ogre's rendering loop or RenderTarget::update is being used.
    @remarks
        By default, if you use Ogre's own rendering loop (Root::startRendering)
        or call RenderTarget::update, all viewports are updated automatically.
        This method allows you to control that behaviour, if for example you 
        have a viewport which you only want to update periodically.
    @param autoupdate If true, the viewport is updated during the automatic
        render loop or when RenderTarget::update() is called. If false, the 
        viewport is only updated when its update() method is called explicitly.
    */
    void setAutoUpdated(bool autoupdate)
    {
        mIsAutoUpdated = autoupdate;
    }
    /** Gets whether this viewport is automatically updated if 
        Ogre's rendering loop or RenderTarget::update is being used.
    */
    bool isAutoUpdated()
    {
        return mIsAutoUpdated;
    }
    
    /** Set the material scheme which the viewport should use.
    @remarks
        This allows you to tell the system to use a particular
        material scheme when rendering this viewport, which can 
        involve using different techniques to render your materials.
    @see Technique::setSchemeName
    */
    void setMaterialScheme(string schemeName)
    { mMaterialSchemeName = schemeName; }
    
    /** Get the material scheme which the viewport should use.
    */
   string getMaterialScheme()
    { return mMaterialSchemeName; }
    
    /** Access to actual dimensions (based on target size).
    */
    void getActualDimensions(
        out int left, out int top, out int width, out int height )
    {
        left = mActLeft;
        top = mActTop;
        width = mActWidth;
        height = mActHeight;
        
    }
    
    bool _isUpdated()
    {
        return mUpdated;
    }
    
    void _clearUpdatedFlag()
    {
        mUpdated = false;
    }
    
    /** Gets the number of rendered faces in the last update.
    */
    uint _getNumRenderedFaces()
    {
        return mCamera ? mCamera._getNumRenderedFaces() : 0;
    }
    
    /** Gets the number of rendered batches in the last update.
    */
    uint _getNumRenderedBatches()
    {
        return mCamera ? mCamera._getNumRenderedBatches() : 0;
    }
    
    /** Tells this viewport whether it should display Overlay objects.
    @remarks
        Overlay objects are layers which appear on top of the scene. They are created via
        SceneManager::createOverlay and every viewport displays these by default.
        However, you probably don't want this if you're using multiple viewports,
        because one of them is probably a picture-in-picture which is not supposed to
        have overlays of it's own. In this case you can turn off overlays on this viewport
        by calling this method.
    @param enabled If true, any overlays are displayed, if false they are not.
    */
    void setOverlaysEnabled(bool enabled)
    {
        mShowOverlays = enabled;
    }
    
    /** Returns whether or not Overlay objects (created in the SceneManager) are displayed in this
        viewport. */
    bool getOverlaysEnabled()
    {
        return mShowOverlays;
    }
    
    /** Tells this viewport whether it should display skies.
    @remarks
        Skies are layers which appear on background of the scene. They are created via
        SceneManager::setSkyBox, SceneManager::setSkyPlane and SceneManager::setSkyDome and
        every viewport displays these by default. However, you probably don't want this if
        you're using multiple viewports, because one of them is probably a picture-in-picture
        which is not supposed to have skies of it's own. In this case you can turn off skies
        on this viewport by calling this method.
    @param enabled If true, any skies are displayed, if false they are not.
    */
    void setSkiesEnabled(bool enabled)
    {
        mShowSkies = enabled;
    }
    
    /** Returns whether or not skies (created in the SceneManager) are displayed in this
        viewport. */
    bool getSkiesEnabled()
    {
        return mShowSkies;
    }
    
    /** Tells this viewport whether it should display shadows.
    @remarks
        This setting enables you to disable shadow rendering for a given viewport. The global
        shadow technique set on SceneManager still controls the type and nature of shadows,
        but this flag can override the setting so that no shadows are rendered for a given
        viewport to save processing time where they are not required.
    @param enabled If true, any shadows are displayed, if false they are not.
    */
    void setShadowsEnabled(bool enabled)
    {
        mShowShadows = enabled;
    }
    
    /** Returns whether or not shadows (defined in the SceneManager) are displayed in this
        viewport. */
    bool getShadowsEnabled()
    {
        return mShowShadows;
    }
    
    
    /** Sets a per-viewport visibility mask.
    @remarks
        The visibility mask is a way to exclude objects from rendering for
        a given viewport. For each object in the frustum, a check is made
        between this mask and the objects visibility flags 
        (@see MovableObject::setVisibilityFlags), and if a binary 'and'
        returns zero, the object will not be rendered.
    */
    void setVisibilityMask(uint mask) { mVisibilityMask = mask; }
    
    /** Gets a per-viewport visibility mask.
    @see Viewport::setVisibilityMask
    */
    uint getVisibilityMask(){ return mVisibilityMask; }
    
    /** Sets the use of a custom RenderQueueInvocationSequence for
        rendering this target.
    @remarks
        RenderQueueInvocationSequence instances are managed through Root. By
        setting this, you are indicating that you wish this RenderTarget to
        be updated using a custom sequence of render queue invocations, with
        potentially customised ordering and render state options. You should
        create the named sequence through Root first, then set the name here.
    @param sequenceName The name of the RenderQueueInvocationSequence to use. If you
        specify a blank string, behaviour will return to the default render
        queue management.
    */
    void setRenderQueueInvocationSequenceName(string sequenceName)
    {
        mRQSequenceName = sequenceName;
        if (mRQSequenceName is null)
        {
            mRQSequence = null;
        }
        else
        {
            mRQSequence =
                Root.getSingleton().getRenderQueueInvocationSequence(mRQSequenceName);
        }
    }
    /** Gets the name of the render queue invocation sequence for this target. */
   string getRenderQueueInvocationSequenceName()
    {
        return mRQSequenceName;
    }
    /// Get the invocation sequence - will return null if using standard
    ref RenderQueueInvocationSequence _getRenderQueueInvocationSequence()
    {
        return mRQSequence;
    }
    
    /** Convert oriented input point coordinates to screen coordinates. */
    void pointOrientedToScreen(Vector2 v, int orientationMode, out Vector2 outv)
    {
        pointOrientedToScreen(v.x, v.y, orientationMode, outv.x, outv.y);
    }
    
    void pointOrientedToScreen(Real orientedX, Real orientedY, int orientationMode,
                               out Real screenX, out Real screenY)
    {
        Real orX = orientedX;
        Real orY = orientedY;
        switch (orientationMode)
        {
            case 1:
                screenX = orY;
                screenY = 1.0 - orX;
                break;
            case 2:
                screenX = 1.0 - orX;
                screenY = 1.0 - orY;
                break;
            case 3:
                screenX = 1.0 - orY;
                screenY = orX;
                break;
            default:
                screenX = orX;
                screenY = orY;
                break;
        }
    }
    
    /// Add a listener to this camera
    void addListener(Listener l)
    {
        if (!mListeners.find(l).length)
            mListeners.insert(l);
    }
    
    /// Remove a listener to this camera
    void removeListener(Listener l)
    {
        mListeners.removeFromArray(l);
    }
    
protected:
    Camera mCamera;
    RenderTarget mTarget;
    // Relative dimensions, irrespective of target dimensions (0..1)
    float mRelLeft, mRelTop, mRelWidth, mRelHeight;
    // Actual dimensions, based on target dimensions
    int mActLeft, mActTop, mActWidth, mActHeight;
    /// ZOrder
    int mZOrder;
    /// Background options
    ColourValue mBackColour;
    Real mDepthClearValue;
    bool mClearEveryFrame;
    uint mClearBuffers;
    bool mUpdated;
    bool mShowOverlays;
    bool mShowSkies;
    bool mShowShadows;
    uint mVisibilityMask;
    // Render queue invocation sequence name
    string mRQSequenceName;
    RenderQueueInvocationSequence mRQSequence;
    /// Material scheme
    string mMaterialSchemeName;
    /// Viewport orientation mode
    OrientationMode mOrientationMode;
    static OrientationMode mDefaultOrientationMode;
    
    /// Automatic rendering on/off
    bool mIsAutoUpdated;
    
    //typedef vector<Listener*>::type ListenerList;
    alias Listener[] ListenerList;
    ListenerList mListeners;
}
