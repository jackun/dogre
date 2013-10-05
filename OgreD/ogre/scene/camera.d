module ogre.scene.camera;
//import std.container;

import ogre.math.frustum;
import ogre.math.plane;
import ogre.math.quaternion;
import ogre.compat;
import ogre.math.maths;
import ogre.math.angles;
import ogre.math.matrix;
import ogre.math.ray;
import ogre.math.axisalignedbox;
import ogre.math.sphere;
import ogre.rendersystem.viewport;
import ogre.math.vector;
import ogre.general.profiler;
import ogre.scene.scenemanager;
import ogre.scene.scenenode;
import ogre.general.common;
import ogre.sharedptr;

/** A viewpoint from which the scene will be rendered.
 @remarks
 OGRE renders scenes from a camera viewpoint into a buffer of
 some sort, normally a window or a texture (a subclass of
 RenderTarget). OGRE cameras support both perspective projection (the default,
 meaning objects get smaller the further away they are) and
 orthographic projection (blueprint-style, no decrease in size
 with distance). Each camera carries with it a style of rendering,
 e.g. full textured, flat shaded, wiref rame), field of view,
 rendering distances etc, allowing you to use OGRE to create
 complex multi-window views if required. In addition, more than
 one camera can point at a single render target if required,
 each rendering to a subset of the target, allowing split screen
 and picture-in-picture views.
 @par
 Cameras maintain their own aspect ratios, field of view, and frustum,
 and project co-ordinates into a space measured from -1 to 1 in x and y,
 and 0 to 1 in z. At render time, the camera will be rendering to a
 Viewport which will translate these parametric co-ordinates into real screen
 co-ordinates. Obviously it is advisable that the viewport has the same
 aspect ratio as the camera to avoid distortion (unless you want it!).
 @par
 Note that a Camera can be attached to a SceneNode, using the method
 SceneNode.attachObject. If this is done the Camera will combine it's own
 position/orientation settings with it's parent SceneNode. 
 This is useful for implementing more complex Camera / object
 relationships i.e. having a camera attached to a world object.
 */
class Camera : Frustum
{
    alias Frustum.getViewMatrix getViewMatrix;
public:
    /** Listener interface so you can be notified of Camera events. 
     */
    interface Listener 
    {
        /// Called prior to the scene being rendered with this camera
        void cameraPreRenderScene(ref Camera cam);
        
        /// Called after the scene has been rendered with this camera
        void cameraPostRenderScene(ref Camera cam);
        
        /// Called when the camera is being destroyed
        void cameraDestroyed(ref Camera cam);
    }
protected:
    /// Scene manager responsible for the scene
    SceneManager mSceneMgr;
    
    /// Camera orientation, quaternion style
    Quaternion mOrientation;
    
    /// Camera position - default (0,0,0)
    Vector3 mPosition;
    
    /// Derived orientation/position of the camera, including reflection
    //mutable 
    Quaternion mDerivedOrientation;
    //mutable 
    Vector3 mDerivedPosition;
    
    /// Real world orientation/position of the camera
    //mutable 
    Quaternion mRealOrientation;
    //mutable 
    Vector3 mRealPosition;
    
    /// Whether to yaw around a fixed axis.
    bool mYawFixed;
    /// Fixed axis to yaw around
    Vector3 mYawFixedAxis;
    
    /// Rendering type
    PolygonMode mSceneDetail;
    
    /// Stored number of visible faces in the last render
    uint mVisFacesLastRender;
    
    /// Stored number of visible faces in the last render
    uint mVisBatchesLastRender;
    
    /// Shared class-level name for Movable type
    static string msMovableType;
    
    /// SceneNode which this Camera will automatically track
    SceneNode mAutoTrackTarget;
    /// Tracking offset for fine tuning
    Vector3 mAutoTrackOffset;
    
    // Scene LOD factor used to adjust overall LOD
    Real mSceneLodFactor;
    /// Inverted scene LOD factor, can be used by Renderables to adjust their LOD
    Real mSceneLodFactorInv;
    
    
    /** Viewing window. 
     @remarks
     Generalize camera class for the case, when viewing frustum doesn't cover all viewport.
     */
    Real mWLeft, mWTop, mWRight, mWBottom;
    /// Is viewing window used.
    bool mWindowSet;
    /// Windowed viewport clip planes 
    //mutable vector<Plane>.type mWindowClipPlanes;
    Plane[] mWindowClipPlanes;
    // Was viewing window changed.
    //mutable 
    bool mRecalcWindow;
    /// The last viewport to be added using this camera
    Viewport mLastViewport;
    /** Whether aspect ratio will automatically be recalculated 
     when a viewport changes its size
     */
    bool mAutoAspectRatio;
    /// Custom culling frustum
    Frustum mCullFrustum;
    /// Whether or not the rendering distance of objects should take effect for this camera
    bool mUseRenderingDistance;
    /// Camera to use for LOD calculation
    //
    Camera mLodCamera;
    
    /// Whether or not the minimum display size of objects should take effect for this camera
    bool mUseMinPixelSize;
    /// @see Camera.getPixelDisplayRatio
    Real mPixelDisplayRatio;
    
    //typedef vector<ref Listener>.type ListenerList;
    alias Listener[] ListenerList;
    ListenerList mListeners;
    
    
    // Internal functions for calcs
    override bool isViewOutOfDate()//
    {
        // Overridden from Frustum to use local orientation / position offsets
        // Attached to node?
        if (mParentNode !is null)
        {
            if (mRecalcView ||
                mParentNode._getDerivedOrientation() != mLastParentOrientation ||
                mParentNode._getDerivedPosition() != mLastParentPosition)
            {
                // Ok, we're out of date with SceneNode we're attached to
                mLastParentOrientation = mParentNode._getDerivedOrientation();
                mLastParentPosition = mParentNode._getDerivedPosition();
                mRealOrientation = mLastParentOrientation * mOrientation;
                mRealPosition = (mLastParentOrientation * mPosition) + mLastParentPosition;
                mRecalcView = true;
                mRecalcWindow = true;
            }
        }
        else
        {
            // Rely on own updates
            mRealOrientation = mOrientation;
            mRealPosition = mPosition;
        }
        
        // Deriving reflection from linked plane?
        if (mReflect && mLinkedReflectPlane && 
            !(mLastLinkedReflectionPlane == mLinkedReflectPlane._getDerivedPlane()))
        {
            mReflectPlane = mLinkedReflectPlane._getDerivedPlane();
            mReflectMatrix = Math.buildReflectionMatrix(cast(Plane)mReflectPlane);
            mLastLinkedReflectionPlane = mLinkedReflectPlane._getDerivedPlane();
            mRecalcView = true;
            mRecalcWindow = true;
        }
        
        // Deriving reflected orientation / position
        if (mRecalcView)
        {
            if (mReflect)
            {
                // Calculate reflected orientation, use up-vector as fallback axis.
                Vector3 dir = mRealOrientation * Vector3.NEGATIVE_UNIT_Z;
                Vector3 rdir = dir.reflect(mReflectPlane.Normal());
                Vector3 up = mRealOrientation * Vector3.UNIT_Y;
                mDerivedOrientation = dir.getRotationTo(rdir, up) * mRealOrientation;
                
                // Calculate reflected position.
                mDerivedPosition = mReflectMatrix.transformAffine(mRealPosition);
            }
            else
            {
                mDerivedOrientation = mRealOrientation;
                mDerivedPosition = mRealPosition;
            }
        }
        
        return mRecalcView;
        
    }
    /// Signal to update frustum information.
    override void invalidateFrustum()//
    {
        mRecalcWindow = true;
        super.invalidateFrustum();
    }
    /// Signal to update view information.
    override void invalidateView()//
    {
        mRecalcWindow = true;
        super.invalidateView();
    }
    
    
    /** Do actual window setting, using parameters set in SetWindow call
     @remarks
     The method will called on demand.
     */
    void setWindowImpl() //const
    {
        if (!mWindowSet || !mRecalcWindow)
            return;
        
        // Calculate general projection parameters
        Real vpLeft, vpRight, vpBottom, vpTop;
        calcProjectionParameters(vpLeft, vpRight, vpBottom, vpTop);
        
        Real vpWidth = vpRight - vpLeft;
        Real vpHeight = vpTop - vpBottom;
        
        Real wvpLeft   = vpLeft + mWLeft * vpWidth;
        Real wvpRight  = vpLeft + mWRight * vpWidth;
        Real wvpTop    = vpTop - mWTop * vpHeight;
        Real wvpBottom = vpTop - mWBottom * vpHeight;
        
        auto vp_ul = Vector3 (wvpLeft, wvpTop, -mNearDist);
        auto vp_ur = Vector3 (wvpRight, wvpTop, -mNearDist);
        auto vp_bl = Vector3 (wvpLeft, wvpBottom, -mNearDist);
        auto vp_br = Vector3 (wvpRight, wvpBottom, -mNearDist);
        
        Matrix4 inv = mViewMatrix.inverseAffine();
        
        Vector3 vw_ul = inv.transformAffine(vp_ul);
        Vector3 vw_ur = inv.transformAffine(vp_ur);
        Vector3 vw_bl = inv.transformAffine(vp_bl);
        Vector3 vw_br = inv.transformAffine(vp_br);
        
        mWindowClipPlanes.clear();
        if (mProjType == ProjectionType.PT_PERSPECTIVE)
        {
            Vector3 position = getPositionForViewUpdate();
            mWindowClipPlanes.insert(new Plane(position, vw_bl, vw_ul));
            mWindowClipPlanes.insert(new Plane(position, vw_ul, vw_ur));
            mWindowClipPlanes.insert(new Plane(position, vw_ur, vw_br));
            mWindowClipPlanes.insert(new Plane(position, vw_br, vw_bl));
        }
        else
        {
            auto x_axis = Vector3(inv[0, 0], inv[0, 1], inv[0, 2]);
            auto y_axis = Vector3(inv[1, 0], inv[1, 1], inv[1, 2]);
            x_axis.normalise();
            y_axis.normalise();
            mWindowClipPlanes.insert(new Plane( x_axis, vw_bl));
            mWindowClipPlanes.insert(new Plane(-x_axis, vw_ur));
            mWindowClipPlanes.insert(new Plane( y_axis, vw_bl));
            mWindowClipPlanes.insert(new Plane(-y_axis, vw_ur));
        }
        
        mRecalcWindow = false;
        
    }
    
    /** Helper function for forwardIntersect that intersects rays with canonical plane */
    //_______________________________________________________
    //|                                                     |
    //| getRayForwardIntersect                              |
    //| -----------------------------                       |
    //| get the intersections of frustum rays with a plane  |
    //| of interest.  The plane is assumed to have constant |
    //| z.  If this is not the case, rays                   |
    //| should be rotated beforehand to work in a           |
    //| coordinate system in which this is true.            |
    //|_____________________________________________________|
    //
    Vector4[] getRayForwardIntersect(Vector3 anchor,Vector3[] dir, Real planeOffset)
    {
        Vector4[] res;
        
        if(!dir.length)
            return res;
        
        int[4] infpt = [0, 0, 0, 0]; // 0=finite, 1=infinite, 2=straddles infinity
        Vector3[4] vec;
        
        // find how much the anchor point must be displaced in the plane's
        // constant variable
        Real delta = planeOffset - anchor.z;
        
        // now set the intersection point and note whether it is a 
        // point at infinity or straddles infinity
        uint i;
        for (i=0; i<4; i++)
        {
            Real test = dir[i].z * delta;
            if (test == 0.0) {
                vec[i] = dir[i];
                infpt[i] = 1;
            }
            else {
                Real lambda = delta / dir[i].z;
                vec[i] = anchor + (lambda * dir[i]);
                if(test < 0.0)
                    infpt[i] = 2;
            }
        }
        
        for (i=0; i<4; i++)
        {
            // store the finite intersection points
            if (infpt[i] == 0)
                res ~= Vector4(vec[i].x, vec[i].y, vec[i].z, 1.0);
            else
            {
                // handle the infinite points of intersection;
                // cases split up into the possible frustum planes 
                // pieces which may contain a finite intersection point
                int nextind = (i+1) % 4;
                int prevind = (i+3) % 4;
                if ((infpt[prevind] == 0) || (infpt[nextind] == 0))
                {
                    if (infpt[i] == 1)
                        res ~= Vector4(vec[i].x, vec[i].y, vec[i].z, 0.0);
                    else
                    {
                        // handle the intersection points that straddle infinity (back-project)
                        if(infpt[prevind] == 0) 
                        {
                            Vector3 temp = vec[prevind] - vec[i];
                            res ~= Vector4(temp.x, temp.y, temp.z, 0.0);
                        }
                        if(infpt[nextind] == 0)
                        {
                            Vector3 temp = vec[nextind] - vec[i];
                            res ~= Vector4(temp.x, temp.y, temp.z, 0.0);
                        }
                    }
                } // end if we need to add an intersection point to the list
            } // end if infinite point needs to be considered
        } // end loop over frustun corners
        
        // we end up with either 0, 3, 4, or 5 intersection points
        
        return res;
    }
    
public:
    /** Standard constructor.
     */
    this(string name, SceneManager sm)
    {
        super(name);
        mSceneMgr = sm;
        mOrientation = Quaternion.IDENTITY;
        mPosition = Vector3.ZERO;
        mSceneDetail = PolygonMode.PM_SOLID;
        //mAutoTrackTarget = null;
        mAutoTrackOffset = Vector3.ZERO;
        mSceneLodFactor = 1.0f;
        mSceneLodFactorInv = 1.0f;
        mWindowSet = false;
        //mLastViewport = 0;
        mAutoAspectRatio = false;
        //mCullFrustum = 0;
        mUseRenderingDistance = true;
        //mLodCamera = 0;
        mUseMinPixelSize = false;
        mPixelDisplayRatio = 0;
        // Reasonable defaults to camera params
        mFOVy = Radian(Math.PI/4.0f);
        mNearDist = 100.0f;
        mFarDist = 100000.0f;
        mAspect = 1.33333333333333f;
        mProjType = ProjectionType.PT_PERSPECTIVE;
        setFixedYawAxis(true);    // Default to fixed yaw, like freelook since most people expect this
        
        invalidateFrustum();
        invalidateView();
        
        // Init matrices
        mViewMatrix = Matrix4.ZERO;
        mProjMatrixRS = Matrix4.ZERO;
        
        //mParentNode = null;
        
        // no reflection
        mReflect = false;
        
        mVisible = false;
        
    }
    
    /** Standard destructor.
     */
    ~this()
    {
        //ListenerList listenersCopy = mListeners;
        foreach (i; mListeners)
        {
            i.cameraDestroyed(this);
        }
    }
    
    /// Add a listener to this camera
    void addListener(ref Listener l)
    {
        if (!inArray(mListeners, l))
            mListeners.insert(l);
    }
    /// Remove a listener to this camera
    void removeListener(ref Listener l)
    {
        mListeners.removeFromArray(l);
    }
    
    /** Returns a pointer to the SceneManager this camera is rendering through.
     */
    ref SceneManager getSceneManager()//
    {
        return mSceneMgr;
    }
    
    /** Sets the level of rendering detail required from this camera.
     @remarks
     Each camera is set to render at full detail by default, that is
     with full texturing, lighting etc. This method lets you change
     that behaviour, allowing you to make the camera just render a
     wiref rame view, for example.
     */
    void setPolygonMode(PolygonMode sd)
    {
        mSceneDetail = sd;
    }
    
    /** Retrieves the level of detail that the camera will render.
     */
    PolygonMode getPolygonMode()
    {
        return mSceneDetail;
    }
    
    /** Sets the camera's position.
     */
    void setPosition(Real x, Real y, Real z)
    {
        mPosition.x = x;
        mPosition.y = y;
        mPosition.z = z;
        invalidateView();
    }
    
    /** Sets the camera's position.
     */
    void setPosition(Vector3 vec)
    {
        mPosition = vec;
        invalidateView();
    }
    
    /** Retrieves the camera's position.
     */
    Vector3 getPosition()
    {
        return mPosition;
    }
    
    /** Moves the camera's position by the vector offset provided along world axes.
     */
    void move(Vector3 vec)
    {
        mPosition = mPosition + vec;
        invalidateView();
    }
    
    /** Moves the camera's position by the vector offset provided along it's own axes (relative to orientation).
     */
    void moveRelative(Vector3 vec)
    {
        // Transform the axes of the relative vector by camera's local axes
        Vector3 trans = mOrientation * vec;
        
        mPosition = mPosition + trans;
        invalidateView();
    }
    
    /** Sets the camera's direction vector.
     @remarks
     Note that the 'up' vector for the camera will automatically be recalculated based on the
     current 'up' vector (i.e. the roll will remain the same).
     */
    void setDirection(Real x, Real y, Real z)
    {
        setDirection(Vector3(x,y,z));
    }
    
    /** Sets the camera's direction vector.
     */
    void setDirection(Vector3 vec)
    {
        // Do nothing if given a zero vector
        // (Replaced assert since this could happen with auto tracking camera and
        //  camera passes through the lookAt point)
        if (vec == Vector3.ZERO) return;
        
        // Remember, camera points down -Z of local axes!
        // Therefore reverse direction of direction vector before determining local Z
        Vector3 zAdjustVec = -vec;
        zAdjustVec.normalise();
        
        Quaternion targetWorldOrientation;
        
        
        if( mYawFixed )
        {
            Vector3 xVec = mYawFixedAxis.crossProduct( zAdjustVec );
            xVec.normalise();
            
            Vector3 yVec = zAdjustVec.crossProduct( xVec );
            yVec.normalise();
            
            targetWorldOrientation.FromAxes( xVec, yVec, zAdjustVec );
        }
        else
        {
            
            // Get axes from current quaternion
            Vector3 axes[3];
            updateView();
            mRealOrientation.ToAxes(axes);
            Quaternion rotQuat;
            if ( (axes[2]+zAdjustVec).squaredLength() <  0.00005f) 
            {
                // Oops, a 180 degree turn (infinite possible rotation axes)
                // Default to yaw i.e. use current UP
                rotQuat.FromAngleAxis(Radian(Math.PI), axes[1]);
            }
            else
            {
                // Derive shortest arc to new direction
                rotQuat = axes[2].getRotationTo(zAdjustVec);
                
            }
            targetWorldOrientation = rotQuat * mRealOrientation;
        }
        
        // transform to parent space
        if (mParentNode)
        {
            mOrientation =
                mParentNode._getDerivedOrientation().Inverse() * targetWorldOrientation;
        }
        else
        {
            mOrientation = targetWorldOrientation;
        }
        
        // TODO If we have a fixed yaw axis, we mustn't break it by using the
        // shortest arc because this will sometimes cause a relative yaw
        // which will tip the camera
        
        invalidateView();
        
    }
    
    /* Gets the camera's direction.
     */
    Vector3 getDirection()
    {
        // Direction points down -Z by default
        return mOrientation * -Vector3.UNIT_Z;
    }
    
    /** Gets the camera's up vector.
     */
    Vector3 getUp()
    {
        return mOrientation * Vector3.UNIT_Y;
    }
    
    /** Gets the camera's right vector.
     */
    Vector3 getRight()
    {
        return mOrientation * Vector3.UNIT_X;
    }
    
    /** Points the camera at a location in worldspace.
     @remarks
     This is a helper method to automatically generate the
     direction vector for the camera, based on it's current position
     and the supplied look-at point.
     @param
     targetPoint A vector specifying the look at point.
     */
    void lookAt(Vector3 targetPoint )
    {
        updateView();
        this.setDirection(targetPoint - mRealPosition);
    }
    /** Points the camera at a location in worldspace.
     @remarks
     This is a helper method to automatically generate the
     direction vector for the camera, based on it's current position
     and the supplied look-at point.
     @param x
     The @c x co-ordinates of the point to look at.
     @param y
     The @c y co-ordinates of the point to look at.
     @param z
     The @c z co-ordinates of the point to look at.
     */
    void lookAt(Real x, Real y, Real z)
    {
        auto vTemp = Vector3( x, y, z );
        this.lookAt(vTemp);
    }
    
    /** Rolls the camera anticlockwise, around its local z axis.
     */
    void roll(Radian angle)
    {
        // Rotate around local Z axis
        Vector3 zAxis = mOrientation * Vector3.UNIT_Z;
        rotate(zAxis, angle);
        
        invalidateView();
    }
    
    /** Rotates the camera anticlockwise around it's local y axis.
     */
    void yaw(Radian angle)
    {
        Vector3 yAxis;
        
        if (mYawFixed)
        {
            // Rotate around fixed yaw axis
            yAxis = mYawFixedAxis;
        }
        else
        {
            // Rotate around local Y axis
            yAxis = mOrientation * Vector3.UNIT_Y;
        }
        
        rotate(yAxis, angle);
        
        invalidateView();
    }
    
    /** Pitches the camera up/down anticlockwise around it's local z axis.
     */
    void pitch(Radian angle)
    {
        // Rotate around local X axis
        Vector3 xAxis = mOrientation * Vector3.UNIT_X;
        rotate(xAxis, angle);
        
        invalidateView();
        
    }
    
    /** Rotate the camera around an arbitrary axis.
     */
    void rotate(Vector3 axis,Radian angle)
    {
        Quaternion q;
        q.FromAngleAxis(angle,axis);
        rotate(q);
    }
    
    /** Rotate the camera around an arbitrary axis using a Quaternion.
     */
    void rotate(Quaternion q)
    {
        // Note the order of the mult, i.e. q comes after
        
        // Normalise the quat to avoid cumulative problems with precision
        Quaternion qnorm = q;
        qnorm.normalise();
        mOrientation = qnorm * mOrientation;
        
        invalidateView();
        
    }
    
    /** Tells the camera whether to yaw around it's own local Y axis or a 
     fixed axis of choice.
     @remarks
     This method allows you to change the yaw behaviour of the camera
     - by default, the camera yaws around a fixed Y axis. This is 
     often what you want - for example if you're making a first-person 
     shooter, you really don't want the yaw axis to reflect the local 
     camera Y, because this would mean a different yaw axis if the 
     player is looking upwards rather than when they are looking
     straight ahead. You can change this behaviour by calling this 
     method, which you will want to do if you are making a completely
     free camera like the kind used in a flight simulator. 
     @param useFixed
     If @c true, the axis passed in the second parameter will 
     always be the yaw axis no matter what the camera orientation. 
     If false, the camera yaws around the local Y.
     @param fixedAxis
     The axis to use if the first parameter is true.
     */
    void setFixedYawAxis( bool useFixed, Vector3 fixedAxis = Vector3.UNIT_Y )
    {
        mYawFixed = useFixed;
        mYawFixedAxis = fixedAxis;
    }
    
    
    /** Returns the camera's current orientation.
     */
    Quaternion getOrientation()
    {
        return mOrientation;
    }
    
    /** Sets the camera's orientation.
     */
    void setOrientation(Quaternion q)
    {
        mOrientation = q;
        mOrientation.normalise();
        invalidateView();
    }
    
    /** Tells the Camera to contact the SceneManager to render from it's viewpoint.
     @param vp The viewport to render to
     @param includeOverlays Whether or not any overlay objects should be included
     */
    void _renderScene(Viewport vp, bool includeOverlays)
    {
        mixin(OgreProfileBeginGPUEvent("Camera: \" ~ getName() ~ \""));
        debug(STDERR) std.stdio.stderr.writeln("Camera._renderScene: ", getName());
        //update the pixel display ratio
        if (mProjType == ProjectionType.PT_PERSPECTIVE)
        {
            mPixelDisplayRatio = (2 * Math.Tan(mFOVy * 0.5f)) / vp.getActualHeight();
        }
        else
        {
            mPixelDisplayRatio = (mTop - mBottom) / vp.getActualHeight();
        }
        
        //notify prerender scene
        ListenerList listenersCopy = mListeners.dup;
        foreach (i; listenersCopy)
        {
            i.cameraPreRenderScene(this);
        }
        
        //render scene
        mSceneMgr._renderScene(this, vp, includeOverlays);
        
        // Listener list may have change
        listenersCopy = mListeners.dup;
        
        //notify postrender scene
        foreach (i; listenersCopy)
        {
            i.cameraPostRenderScene(this);
        }
        mixin(OgreProfileEndGPUEvent("Camera: \" ~ getName() ~ \""));
    }
    
    /** Function for outputting to a stream.
     */
    override string toString()
    {
        string o = std.conv.text("Camera(Name='", mName, "', pos=", mPosition);
        auto dir = mOrientation*Vector3(0,0,-1);
        o ~= std.conv.text(", direction=", dir,  ",near=",  mNearDist,
                           ", far=",   mFarDist,  ", FOVy=",  mFOVy.valueDegrees(),
                           ", aspect=",  mAspect,  ", ",
                           ", xoffset=",  mFrustumOffset.x,  ", yoffset=",  mFrustumOffset.y,
                           ", focalLength=",  mFocalLength,  ", ",
                           "NearFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_NEAR],  ", ",
                           "FarFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_FAR],  ", ",
                           "LeftFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT],  ", ",
                           "RightFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT],  ", ",
                           "TopFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP],  ", ",
                           "BottomFrustumPlane=",  mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM],
                           ")");
        
        return o;
    }
    
    /** Internal method to notify camera of the visible faces in the last render.
     */
    void _notifyRenderedFaces(uint numfaces)
    {
        mVisFacesLastRender = numfaces;
    }
    
    /** Internal method to notify camera of the visible batches in the last render.
     */
    void _notifyRenderedBatches(uint numbatches)
    {
        mVisBatchesLastRender = numbatches;
    }
    
    /** Internal method to retrieve the number of visible faces in the last render.
     */
    uint _getNumRenderedFaces()
    {
        return mVisFacesLastRender;
    }
    
    /** Internal method to retrieve the number of visible batches in the last render.
     */
    uint _getNumRenderedBatches()
    {
        return mVisBatchesLastRender;
    }
    
    /** Gets the derived orientation of the camera, including any
     rotation inherited from a node attachment and reflection matrix. */
   Quaternion getDerivedOrientation()
    {
        updateView();
        return mDerivedOrientation;
    }
    /** Gets the derived position of the camera, including any
     translation inherited from a node attachment and reflection matrix. */
   Vector3 getDerivedPosition()
    {
        updateView();
        debug(STDERR) std.stdio.stderr.writeln("Camera.getDerivedPosition: ", mDerivedPosition);
        return mDerivedPosition;
    }
    /** Gets the derived direction vector of the camera, including any
     rotation inherited from a node attachment and reflection matrix. */
    Vector3 getDerivedDirection()
    {
        // Direction points down -Z
        updateView();
        return mDerivedOrientation * Vector3.NEGATIVE_UNIT_Z;
    }
    /** Gets the derived up vector of the camera, including any
     rotation inherited from a node attachment and reflection matrix. */
    Vector3 getDerivedUp()
    {
        updateView();
        return mDerivedOrientation * Vector3.UNIT_Y;
    }
    /** Gets the derived right vector of the camera, including any
     rotation inherited from a node attachment and reflection matrix. */
    Vector3 getDerivedRight()
    {
        updateView();
        return mDerivedOrientation * Vector3.UNIT_X;
    }
    
    /** Gets the real world orientation of the camera, including any
     rotation inherited from a node attachment */
   Quaternion getRealOrientation()
    {
        updateView();
        return mRealOrientation;
    }
    /** Gets the real world position of the camera, including any
     translation inherited from a node attachment. */
   Vector3 getRealPosition()
    {
        updateView();
        return mRealPosition;
    }
    /** Gets the real world direction vector of the camera, including any
     rotation inherited from a node attachment. */
    Vector3 getRealDirection()
    {
        // Direction points down -Z
        updateView();
        return mRealOrientation * Vector3.NEGATIVE_UNIT_Z;
    }
    /** Gets the real world up vector of the camera, including any
     rotation inherited from a node attachment. */
    Vector3 getRealUp()
    {
        updateView();
        return mRealOrientation * Vector3.UNIT_Y;
    }
    /** Gets the real world right vector of the camera, including any
     rotation inherited from a node attachment. */
    Vector3 getRealRight()
    {
        updateView();
        return mRealOrientation * Vector3.UNIT_X;
    }
    
    /** Overridden from Frustum/Renderable */
    override void getWorldTransforms(ref Matrix4[] mat) //const
    {
        updateView();
        
        auto scale = Vector3(1.0, 1.0, 1.0);
        if (mParentNode)
            scale = mParentNode._getDerivedScale();

        Matrix4 tmp;
        tmp.makeTransform(
            mDerivedPosition,
            scale,
            mDerivedOrientation);

        insertOrReplace(mat, tmp);
    }
    
    /** Overridden from MovableObject */
    override string getMovableType()
    {
        return msMovableType;
    }
    
    /** Enables / disables automatic tracking of a SceneNode.
     @remarks
     If you enable auto-tracking, this Camera will automatically rotate to
     look at the target SceneNode every frame, no matter how 
     it or SceneNode move. This is handy if you want a Camera to be focused on a
     single object or group of objects. Note that by default the Camera looks at the 
     origin of the SceneNode, if you want to tweak this, e.g. if the object which is
     attached to this target node is quite big and you want to point the camera at
     a specific point on it, provide a vector in the 'offset' parameter and the 
     camera's target point will be adjusted.
     @param enabled If true, the Camera will track the SceneNode supplied as the next 
     parameter (cannot be null). If false the camera will cease tracking and will
     remain in it's current orientation.
     @param target Pointer to the SceneNode which this Camera will track. Make sure you don't
     delete this SceneNode before turning off tracking (e.g. SceneManager.clearScene will
     delete it so be caref ul of this). Can be null if and only if the enabled param is false.
     @param offset If supplied, the camera targets this point in local space of the target node
     instead of the origin of the target node. Good for fine tuning the look at point.
     */
    void setAutoTracking(bool enabled, SceneNode target = null, 
                        Vector3 offset = Vector3.ZERO)
    {
        if (enabled)
        {
            assert (target !is null, "target cannot be a null pointer if tracking is enabled");
            mAutoTrackTarget = target;
            mAutoTrackOffset = offset;
        }
        else
        {
            mAutoTrackTarget = null;
        }
    }
    
    
    /** Sets the level-of-detail factor for this Camera.
     @remarks
     This method can be used to influence the overall level of detail of the scenes 
     rendered using this camera. Various elements of the scene have level-of-detail
     reductions to improve rendering speed at distance; this method allows you 
     to hint to those elements that you would like to adjust the level of detail that
     they would normally use (up or down). 
     @par
     The most common use for this method is to reduce the overall level of detail used
     for a secondary camera used for sub viewports like rear-view mirrors etc.
     Note that scene elements are at liberty to ignore this setting if they choose,
     this is merely a hint.
     @param factor The factor to apply to the usual level of detail calculation. Higher
     values increase the detail, so 2.0 doubles the normal detail and 0.5 halves it.
     */
    void setLodBias(Real factor = 1.0)
    {
        assert(factor > 0.0f && "Bias factor must be > 0!");
        mSceneLodFactor = factor;
        mSceneLodFactorInv = 1.0f / factor;
    }
    
    /** Returns the level-of-detail bias factor currently applied to this camera. 
     @remarks
     See Camera.setLodBias for more details.
     */
    Real getLodBias()
    {
        return mSceneLodFactor;
    }
    
    /** Get a pointer to the camera which should be used to determine 
     LOD settings. 
     @remarks
     Sometimes you don't want the LOD of a render to be based on the camera
     that's doing the rendering, you want it to be based on a different
     camera. A good example is when rendering shadow maps, since they will 
     be viewed from the perspective of another camera. Therefore this method
     lets you associate a different camera instance to use to determine the LOD.
     @par
     To revert the camera to determining LOD based on itself, call this method with 
     a pointer to itself. 
     */
    void setLodCamera(ref Camera lodCam)
    {
        if (lodCam == this)
            mLodCamera = null;
        else
            mLodCamera = lodCam;
    }
    
    /** Get a pointer to the camera which should be used to determine 
     LOD settings. 
     @remarks
     If setLodCamera hasn't been called with a different camera, this
     method will return 'this'. 
     */
    ref Camera getLodCamera()
    {
        return mLodCamera? mLodCamera : this;
    }
    
    /** Internal method for OGRE to use for LOD calculations. */
    Real _getLodBiasInverse()
    {
        return mSceneLodFactorInv;
    }
    
    
    /** Internal method used by OGRE to update auto-tracking cameras. */
    void _autoTrack()
    {
        // NB assumes that all scene nodes have been updated
        if (mAutoTrackTarget)
        {
            lookAt(mAutoTrackTarget._getDerivedPosition() + mAutoTrackOffset);
        }
    }
    
    /** Gets a world space ray as cast from the camera through a viewport position.
     @param screenx, screeny The x and y position at which the ray should intersect the viewport, 
     in normalised screen coordinates [0,1]
     */
    Ray getCameraToViewportRay(Real screenX, Real screenY)
    {
        Ray ret;
        getCameraToViewportRay(screenX, screenY, ret);
        return ret;
    }
    /** Gets a world space ray as cast from the camera through a viewport position.
     @param screenx, screeny The x and y position at which the ray should intersect the viewport, 
     in normalised screen coordinates [0,1]
     @param outRay Ray instance to populate with result
     */
    void getCameraToViewportRay(Real screenX, Real screenY, out Ray outRay)
    {
        Matrix4 inverseVP = (getProjectionMatrix() * getViewMatrix(true)).inverse();
        
        version (OGRE_NO_VIEWPORT_ORIENTATIONMODE)
        {
            // We need to convert screen point to our oriented viewport (temp solution)
            Real tX = screenX; Real a = getOrientationMode() * Math.HALF_PI;
            screenX = Math.Cos(a) * (tX-0.5f) + Math.Sin(a) * (screenY-0.5f) + 0.5f;
            screenY = Math.Sin(a) * (tX-0.5f) + Math.Cos(a) * (screenY-0.5f) + 0.5f;
            if (cast(int)getOrientationMode()&1) screenY = 1.0f - screenY;
        }
        
        Real nx = (2.0f * screenX) - 1.0f;
        Real ny = 1.0f - (2.0f * screenY);
        auto nearPoint = Vector3(nx, ny, -1.0f);
        // Use midPoint rather than far point to avoid issues with infinite projection
        auto midPoint = Vector3(nx, ny,  0.0f);
        
        // Get ray origin and ray target on near plane in world space
        Vector3 rayOrigin, rayTarget;
        
        rayOrigin = inverseVP * nearPoint;
        rayTarget = inverseVP * midPoint;
        
        Vector3 rayDirection = rayTarget - rayOrigin;
        rayDirection.normalise();
        
        outRay.setOrigin(rayOrigin);
        outRay.setDirection(rayDirection);
    } 
    
    /** Gets a world-space list of planes enclosing a volume based on a viewport
     rectangle. 
     @remarks
     Can be useful for populating a PlaneBoundedVolumeListSceneQuery, e.g. 
     for a rubber-band selection. 
     @param screenLeft, screenTop, screenRight, screenBottom The bounds of the
     on-screen rectangle, expressed in normalised screen coordinates [0,1]
     @param includeFarPlane If true, the volume is truncated by the camera far plane, 
     by default it is left open-ended
     */
    PlaneBoundedVolume getCameraToViewportBoxVolume(Real screenLeft, 
                                                    Real screenTop, Real screenRight, Real screenBottom, bool includeFarPlane = false)
    {
        PlaneBoundedVolume vol;
        getCameraToViewportBoxVolume(screenLeft, screenTop, screenRight, screenBottom, 
                                     vol, includeFarPlane);
        return vol;
        
    }
    
    /** Gets a world-space list of planes enclosing a volume based on a viewport
     rectangle. 
     @remarks
     Can be useful for populating a PlaneBoundedVolumeListSceneQuery, e.g. 
     for a rubber-band selection. 
     @param screenLeft, screenTop, screenRight, screenBottom The bounds of the
     on-screen rectangle, expressed in normalised screen coordinates [0,1]
     @param outVolume The plane list to populate with the result
     @param includeFarPlane If true, the volume is truncated by the camera far plane, 
     by default it is left open-ended
     */
    void getCameraToViewportBoxVolume(Real screenLeft, 
                                      Real screenTop, Real screenRight, Real screenBottom, 
                                      ref PlaneBoundedVolume outVolume, bool includeFarPlane = false)
    {
        outVolume.planes.clear();
        
        if (mProjType == ProjectionType.PT_PERSPECTIVE)
        {
            
            // Use the corner rays to generate planes
            Ray ul = getCameraToViewportRay(screenLeft, screenTop);
            Ray ur = getCameraToViewportRay(screenRight, screenTop);
            Ray bl = getCameraToViewportRay(screenLeft, screenBottom);
            Ray br = getCameraToViewportRay(screenRight, screenBottom);
            
            
            Vector3 normal;
            // top plane
            normal = ul.getDirection().crossProduct(ur.getDirection());
            normal.normalise();
            outVolume.planes.insert(
                new Plane(normal, getDerivedPosition()));
            
            // right plane
            normal = ur.getDirection().crossProduct(br.getDirection());
            normal.normalise();
            outVolume.planes.insert(
                new Plane(normal, getDerivedPosition()));
            
            // bottom plane
            normal = br.getDirection().crossProduct(bl.getDirection());
            normal.normalise();
            outVolume.planes.insert(
                new Plane(normal, getDerivedPosition()));
            
            // left plane
            normal = bl.getDirection().crossProduct(ul.getDirection());
            normal.normalise();
            outVolume.planes.insert(
                new Plane(normal, getDerivedPosition()));
            
        }
        else
        {
            // ortho planes are parallel to frustum planes
            
            Ray ul = getCameraToViewportRay(screenLeft, screenTop);
            Ray br = getCameraToViewportRay(screenRight, screenBottom);
            
            updateFrustumPlanes();
            outVolume.planes.insert(
                new Plane(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_TOP].normal, ul.getOrigin()));
            outVolume.planes.insert(
                new Plane(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_RIGHT].normal, br.getOrigin()));
            outVolume.planes.insert(
                new Plane(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_BOTTOM].normal, br.getOrigin()));
            outVolume.planes.insert(
                new Plane(mFrustumPlanes[FrustumPlane.FRUSTUM_PLANE_LEFT].normal, ul.getOrigin()));
            
            
        }
        
        // near & far plane applicable to both projection types
        outVolume.planes.insert(getFrustumPlane(FrustumPlane.FRUSTUM_PLANE_NEAR));
        if (includeFarPlane)
            outVolume.planes.insert(getFrustumPlane(FrustumPlane.FRUSTUM_PLANE_FAR));
    }
    
    /** Sets the viewing window inside of viewport.
     @remarks
     This method can be used to set a subset of the viewport as the rendering
     target. 
     @param left Relative to Viewport - 0 corresponds to left edge, 1 - to right edge (default - 0).
     @param top Relative to Viewport - 0 corresponds to top edge, 1 - to bottom edge (default - 0).
     @param right Relative to Viewport - 0 corresponds to left edge, 1 - to right edge (default - 1).
     @param bottom Relative to Viewport - 0 corresponds to top edge, 1 - to bottom edge (default - 1).
     */
    void setWindow (Real left, Real top, Real right, Real bottom)
    {
        mWLeft = left;
        mWTop = top;
        mWRight = right;
        mWBottom = bottom;
        
        mWindowSet = true;
        mRecalcWindow = true;
    }
    
    /// Cancel view window.
    void resetWindow ()
    {
        mWindowSet = false;
    }
    /// Returns if a viewport window is being used
    bool isWindowSet(){ return mWindowSet; }
    /// Gets the window clip planes, only applicable if isWindowSet == true
    //
    Plane[] getWindowPlanes()//
    {
        updateView();
        setWindowImpl();
        return mWindowClipPlanes;
    }
    
    /** Overridden from MovableObject */
    override Real getBoundingRadius()
    {
        // return a little bigger than the near distance
        // just to keep things just outside
        return mNearDist * 1.5f;
        
    }
    /** Get the auto tracking target for this camera, if any. */
    ref SceneNode getAutoTrackTarget() { return mAutoTrackTarget; }
    /** Get the auto tracking offset for this camera, if it is auto tracking. */
    Vector3 getAutoTrackOffset(){ return mAutoTrackOffset; }
    
    /** Get the last viewport which was attached to this camera. 
     @note This is not guaranteed to be the only viewport which is
     using this camera, just the last once which was created ref erring
     to it.
     */
    ref Viewport getViewport(){return mLastViewport;}
    /** Notifies this camera that a viewport is using it.*/
    void _notifyViewport(Viewport viewport) {mLastViewport = viewport;}
    
    /** If set to true a viewport that owns this frustum will be able to 
     recalculate the aspect ratio whenever the frustum is resized.
     @remarks
     You should set this to true only if the frustum / camera is used by 
     one viewport at the same time. Otherwise the aspect ratio for other 
     viewports may be wrong.
     */    
    void setAutoAspectRatio(bool autoratio)
    {
        mAutoAspectRatio = autoratio;
    }
    
    /** Retrieves if AutoAspectRatio is currently set or not
     */
    bool getAutoAspectRatio()
    {
        return mAutoAspectRatio;
    }
    
    /** Tells the camera to use a separate Frustum instance to perform culling.
     @remarks
     By calling this method, you can tell the camera to perform culling
     against a different frustum to it's own. This is mostly useful for
     debug cameras that allow you to show the culling behaviour of another
     camera, or a manual frustum instance. 
     @param frustum Pointer to a frustum to use; this can either be a manual
     Frustum instance (which you can attach to scene nodes like any other
     MovableObject), or another camera. If you pass 0 to this method it
     reverts the camera to normal behaviour.
     */
    void setCullingFrustum(ref Frustum frustum) { mCullFrustum = frustum; }
    /** Returns the custom culling frustum in use. */
    ref Frustum getCullingFrustum(){ return mCullFrustum; }
    
    /** Forward projects frustum rays to find forward intersection with plane.
     @remarks
     Forward projection may lead to intersections at infinity.
     */
    void forwardIntersect(ref Plane worldPlane, ref Vector4[] intersect3d)
    {
        if(!intersect3d)
            return;
        
        Vector3 trCorner = getWorldSpaceCorners()[0];
        Vector3 tlCorner = getWorldSpaceCorners()[1];
        Vector3 blCorner = getWorldSpaceCorners()[2];
        Vector3 brCorner = getWorldSpaceCorners()[3];
        
        // need some sort of rotation that will bring the plane normal to the z axis
        Plane pval = worldPlane;
        if(pval.normal.z < 0.0)
        {
            pval.normal *= -1.0;
            pval.d *= -1.0;
        }
        Quaternion invPlaneRot = pval.normal.getRotationTo(Vector3.UNIT_Z);
        
        // get rotated light
        Vector3 lPos = invPlaneRot * getDerivedPosition();
        Vector3 vec[4];
        vec[0] = invPlaneRot * trCorner - lPos;
        vec[1] = invPlaneRot * tlCorner - lPos; 
        vec[2] = invPlaneRot * blCorner - lPos; 
        vec[3] = invPlaneRot * brCorner - lPos; 
        
        // compute intersection points on plane
        Vector4[] iPnt = getRayForwardIntersect(lPos, vec, -pval.d);
        
        
        // return wanted data
        if(intersect3d) 
        {
            Quaternion planeRot = invPlaneRot.Inverse();
            intersect3d.clear();
            foreach(point; iPnt)
            {
                Vector3 intersection = planeRot * Vector3(point.x, point.y, point.z);
                intersect3d.insert(Vector4(intersection.x, intersection.y, intersection.z, point.w));
            }
        }
    }
    
    /// @copydoc Frustum.isVisible(AxisAlignedBox, ref FrustumPlane)
    override bool isVisible(AxisAlignedBox bound, FrustumPlane* culledBy/*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        if (mCullFrustum)
        {
            return mCullFrustum.isVisible(bound, culledBy);
        }
        else
        {
            return super.isVisible(bound, culledBy);
        }
    }
    /// @copydoc Frustum.isVisible(Sphere, ref FrustumPlane)
    override bool isVisible(Sphere bound, FrustumPlane* culledBy  /*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        if (mCullFrustum)
        {
            return mCullFrustum.isVisible(bound, culledBy);
        }
        else
        {
            return super.isVisible(bound, culledBy);
        }
    }
    /// @copydoc Frustum.isVisible(Vector3, ref FrustumPlane)
    override bool isVisible(Vector3 vert, FrustumPlane* culledBy /*= FrustumPlane.FRUSTUM_PLANE_NEAR*/)
    {
        if (mCullFrustum)
        {
            return mCullFrustum.isVisible(vert, culledBy);
        }
        else
        {
            return super.isVisible(vert, culledBy);
        }
    }
    /// @copydoc Frustum.getWorldSpaceCorners
    override ref Vector3[8] getWorldSpaceCorners()
    {
        if (mCullFrustum)
        {
            return mCullFrustum.getWorldSpaceCorners();
        }
        else
        {
            return super.getWorldSpaceCorners();
        }
    }
    /// @copydoc Frustum.getFrustumPlane
    override ref Plane getFrustumPlane( ushort plane )
    {
        if (mCullFrustum)
        {
            return mCullFrustum.getFrustumPlane(plane);
        }
        else
        {
            return super.getFrustumPlane(plane);
        }
    }
    /// @copydoc Frustum.projectSphere
    override bool projectSphere(Sphere sphere, 
                                ref Real left, ref Real top, ref Real right, ref Real bottom)
    {
        if (mCullFrustum)
        {
            return mCullFrustum.projectSphere(sphere, left, top, right, bottom);
        }
        else
        {
            return super.projectSphere(sphere, left, top, right, bottom);
        }
    }
    /// @copydoc Frustum.getNearClipDistance
    override Real getNearClipDistance()
    {
        if (mCullFrustum)
        {
            return mCullFrustum.getNearClipDistance();
        }
        else
        {
            return Frustum.getNearClipDistance();
        }
    }
    /// @copydoc Frustum.getFarClipDistance
    override Real getFarClipDistance()
    {
        if (mCullFrustum)
        {
            return mCullFrustum.getFarClipDistance();
        }
        else
        {
            return Frustum.getFarClipDistance();
        }
    }
    /// @copydoc Frustum.getViewMatrix
    override Matrix4 getViewMatrix() const
    {
        if (mCullFrustum)
        {
            return mCullFrustum.getViewMatrix();
        }
        else
        {
            return Frustum.getViewMatrix();
        }
    }
    /** Specialised version of getViewMatrix allowing caller to differentiate
     whether the custom culling frustum should be allowed or not. 
     @remarks
     The default behaviour of the standard getViewMatrix is to delegate to 
     the alternate culling frustum, if it is set. This is expected when 
     performing CPU calculations, but the final rendering must be performed
     using the real view matrix in order to display the correct debug view.
     */
    Matrix4 getViewMatrix(bool ownFrustumOnly)
    {
        if (ownFrustumOnly)
        {
            return Frustum.getViewMatrix();
        }
        else
        {
            return getViewMatrix();
        }
    }
    /** Set whether this camera should use the 'rendering distance' on
     objects to exclude distant objects from the final image. The
     default behaviour is to use it.
     @param use True to use the rendering distance, false not to.
     */
    void setUseRenderingDistance(bool use) { mUseRenderingDistance = use; }
    /** Get whether this camera should use the 'rendering distance' on
     objects to exclude distant objects from the final image.
     */
    bool getUseRenderingDistance(){ return mUseRenderingDistance; }
    
    /** Synchronise core camera settings with another. 
     @remarks
     Copies the position, orientation, clip distances, projection type, 
     FOV, focal length and aspect ratio from another camera. Other settings like query flags, 
     reflection etc are preserved.
     */
    void synchroniseBaseSettingsWith(ref Camera cam)
    {
        this.setPosition(cam.getPosition());
        this.setProjectionType(cam.getProjectionType());
        this.setOrientation(cam.getOrientation());
        this.setAspectRatio(cam.getAspectRatio());
        this.setNearClipDistance(cam.getNearClipDistance());
        this.setFarClipDistance(cam.getFarClipDistance());
        this.setUseRenderingDistance(cam.getUseRenderingDistance());
        this.setFOVy(cam.getFOVy());
        this.setFocalLength(cam.getFocalLength());
        
        // Don't do these, they're not base settings and can cause ref erencing issues
        //this.setLodCamera(cam.getLodCamera());
        //this.setCullingFrustum(cam.getCullingFrustum());
        
    }
    
    /** Get the derived position of this frustum. */
    override Vector3 getPositionForViewUpdate()
    {
        // Note no update, because we're calling this from the update!
        return mRealPosition;
    }
    /** Get the derived orientation of this frustum. */
    override Quaternion getOrientationForViewUpdate()
    {
        return mRealOrientation;
    }
    
    /** @brief Sets whether to use min display size calculations.
     When active objects who's size on the screen is less then a given number will not
     be rendered.
     */
    void setUseMinPixelSize(bool enable) { mUseMinPixelSize = enable; }
    /** Returns whether to use min display size calculations 
     @see Camera.setUseMinDisplaySize
     */
    bool getUseMinPixelSize(){ return mUseMinPixelSize; }
    
    /** Returns an estimated ratio between a pixel and the display area it represents.
     For orthographic cameras this function returns the amount of meters covered by
     a single pixel along the vertical axis. For perspective cameras the value
     returned is the amount of meters covered by a single pixel per meter distance 
     from the camera.
     @note
     This parameter is calculated just before the camera is rendered
     @note
     This parameter is used in min display size calculations.
     */
    Real getPixelDisplayRatio(){ return mPixelDisplayRatio; }
    
}