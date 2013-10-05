module ogre.scene.movableobject;

import ogre.animation.animations;
import ogre.animation.animable;
import ogre.compat;
import ogre.general.common;
import ogre.math.axisalignedbox;
import ogre.math.sphere;
import ogre.math.matrix;
import ogre.math.edgedata;
import ogre.rendersystem.renderqueue;
import ogre.general.root;
import ogre.math.frustum;
import ogre.lod.lodstrategy;
import ogre.scene.shadowcaster;
import ogre.scene.scenemanager;
import ogre.scene.node;
import ogre.scene.camera;
import ogre.scene.userobjectbindings;
import ogre.scene.scenenode;
import ogre.scene.light;
import ogre.rendersystem.hardware;
import ogre.scene.renderable;
import ogre.math.maths;
import ogre.sharedptr;

/** Abstract class defining a movable object in a scene.
    @remarks
        Instances of this class are discrete, relatively small, movable objects
        which are attached to SceneNode objects to define their position.
*/
class MovableObject : ShadowCaster, AnimableObject//, public MovableAlloc
{
    mixin AnimableObject.AnimableObject_Members!();
    mixin AnimableObject.AnimableObject_Impl!();
    //TODO Make derivatives implement Renderable_Any_Impl ,so less 'override' errors
    //mixin Renderable.Renderable_Any_Impl;
    
public:
    /** Listener which gets called back on MovableObject events.
    */
    class Listener //TODO Could be a interface?
    {
    public:
        this() {}
        ~this() {}
        /** MovableObject is being destroyed */
        void objectDestroyed(MovableObject) {}
        /** MovableObject has been attached to a node */
        void objectAttached(MovableObject) {}
        /** MovableObject has been detached from a node */
        void objectDetached(MovableObject) {}
        /** MovableObject has been moved */
        void objectMoved(MovableObject){}
        /** Called when the movable object of the camera to be used for rendering.
        @return
            true if allows queue for rendering, false otherwise.
        */
        bool objectRendering(MovableObject,Camera) { return true; }
        /** Called when the movable object needs to query a light list.
        @remarks
            If you want to customize light finding for this object, you should override 
            this method and hook into MovableObject via MovableObject.setListener.
            Be aware that the default method caches results within a frame to 
            prevent unnecessary recalculation, so if you override this you 
            should provide your own caching to maintain performance.
        @note
            If you use texture shadows, there is an additional restriction - 
            since the lights which should have shadow textures rendered for
            them are determined based on the entire frustum, and not per-object,
         it is important that the lights returned at the start of this 
            list (up to the number of shadow textures available) are the same 
            lights that were used to generate the shadow textures, 
            and they are in the same order (particularly for additive effects).
        @note
            This method will not be called for additive stencil shadows since the
            light list cannot be varied per object with this technique.
        @return
            A pointer to a light list if you populated the light list yourself, or
            null to fall back on the default finding process.
        */
       LightList *objectQueryLights(MovableObject) { return null; }
    }
    
protected:
    /// Name of this object
    string mName;
    /// Creator of this object (if created by a factory)
    MovableObjectFactory mCreator;
    /// SceneManager holding this object (if applicable)
    SceneManager mManager;
    /// node to which this object is attached
    Node mParentNode;
    bool mParentIsTagPoint;
    /// Is this object visible?
    bool mVisible;
    /// Is debug display enabled?
    bool mDebugDisplay;
    /// Upper distance to still render
    Real mUpperDistance;
    Real mSquaredUpperDistance;
    // Minimum pixel size to still render
    Real mMinPixelSize;
    /// Hidden because of distance?
    bool mBeyondFarDistance;    
    /// User objects binding.
    UserObjectBindings mUserObjectBindings;
    /// The render queue to use when rendering this object
    ubyte mRenderQueueID;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueueIDSet;
    /// The render queue group to use when rendering this object
    ushort mRenderQueuePriority;
    /// Flags whether the RenderQueue's default should be used.
    bool mRenderQueuePrioritySet;
    /// Flags determining whether this object is included / excluded from scene queries
    uint mQueryFlags;
    /// Flags determining whether this object is visible (compared to SceneManager mask)
    uint mVisibilityFlags;
    /// Cached world AABB of this object
    //mutable 
    AxisAlignedBox mWorldAABB;
    // Cached world bounding sphere
    //mutable 
    Sphere mWorldBoundingSphere;
    /// World space AABB of this object's dark cap
    //mutable 
    AxisAlignedBox mWorldDarkCapBounds;
    /// Does this object cast shadows?
    bool mCastShadows;
    
    /// Does rendering this object disabled by listener?
    bool mRenderingDisabled;
    /// MovableObject listener - only one allowed (no list) for size & performance reasons. */
    Listener mListener;
    
    /// List of lights for this object
    //mutable 
    LightList mLightList;
    /// The last frame that this light list was updated in
    //mutable 
    ulong mLightListUpdated;
    
    /// the light mask defined for this movable. This will be taken into consideration when deciding which light should affect this movable
    uint mLightMask;
    
    // Static members
    /// Default query flags
    static uint msDefaultQueryFlags = 0xFFFFFFFF;
    /// Default visibility flags
    static uint msDefaultVisibilityFlags = 0xFFFFFFFF;
    
    
    
public:
    /// Constructor
    this()
    {
        //mCreator = null;
        //mManager = null;
        //mParentNode = null;
        mParentIsTagPoint = false;
        mVisible = true;
        mDebugDisplay = false;
        mUpperDistance = 0;
        mSquaredUpperDistance = 0;
        mMinPixelSize = 0;
        mBeyondFarDistance = false;
        mRenderQueueID = RenderQueueGroupID.RENDER_QUEUE_MAIN;
        mRenderQueueIDSet = false;
        mRenderQueuePriority = 100;
        mRenderQueuePrioritySet = false;
        mQueryFlags = msDefaultQueryFlags;
        mVisibilityFlags = msDefaultVisibilityFlags;
        mCastShadows = true;
        mRenderingDisabled = false;
        //mListener = null;
        mLightListUpdated = 0;
        
        mLightMask = 0xFFFFFFFF;
        
        if (Root.getSingletonPtr())
            mMinPixelSize = Root.getSingleton().getDefaultMinPixelSize();
    }
    
    /// Named constructor
    this(string name)
    {
        mName = name;
        //mCreator = null;
        //mManager = null;
        //mParentNode = null;
        mParentIsTagPoint = false;
        mVisible = true;
        mDebugDisplay = false;
        mUpperDistance = 0;
        mSquaredUpperDistance = 0;
        mMinPixelSize = 0;
        mBeyondFarDistance = false;
        mRenderQueueID = RenderQueueGroupID.RENDER_QUEUE_MAIN;
        mRenderQueueIDSet = false;
        mRenderQueuePriority = 100;
        mRenderQueuePrioritySet = false;
        mQueryFlags = msDefaultQueryFlags;
        mVisibilityFlags = msDefaultVisibilityFlags;
        mCastShadows = true;
        mRenderingDisabled = false;
        //mListener = null;
        mLightListUpdated = 0;
        
        mLightMask = 0xFFFFFFFF;
        if (Root.getSingleton())
            mMinPixelSize = Root.getSingleton().getDefaultMinPixelSize();
    }
    
    /** destructor - read Scott Meyers if you don't know why this is needed.
    */
    ~this()
    {
        // Call listener (note, only called if there's something to do)
        if (mListener)
        {
            mListener.objectDestroyed(this);
        }
        
        if (mParentNode)
        {
            // detach from parent
            if (mParentIsTagPoint)
            {
                // May be we are a lod entity which not in the parent entity child object list,
                // call this method could safely ignore this case.
                (cast(TagPoint)mParentNode).getParentEntity().detachObjectFromBone(this);
            }
            else
            {
                // May be we are a lod entity which not in the parent node child object list,
                // call this method could safely ignore this case.
                (cast(SceneNode)mParentNode).detachObject(this);
            }
        }
    }
    
    /** Notify the object of it's creator (internal use only) */
    void _notifyCreator(MovableObjectFactory fact) { mCreator = fact; }
    /** Get the creator of this object, if any (internal use only) */
    MovableObjectFactory  _getCreator(){ return mCreator; }
    /** Notify the object of it's manager (internal use only) */
    void _notifyManager(SceneManager man) { mManager = man; }
    /** Get the manager of this object, if any (internal use only) */
    SceneManager _getManager(){ return mManager; }
    
    /** Returns the name of this object. */
    string getName(){ return mName; }
    
    /** Returns the type name of this object. */
    abstract string getMovableType();
    
    /** Returns the node to which this object is attached.
    @remarks
        A MovableObject may be attached to either a SceneNode or to a TagPoint, 
        the latter case if it's attached to a bone on an animated entity. 
        Both are Node subclasses so this method will return either.
    */
    Node getParentNode()
    {
        return mParentNode;
    }

    /** Returns the scene node to which this object is attached.
    @remarks
        A MovableObject may be attached to either a SceneNode or to a TagPoint, 
        the latter case if it's attached to a bone on an animated entity. 
        This method will return the scene node of the parent entity 
        if the latter is true.
    */
    SceneNode getParentSceneNode()
    {
        if (mParentIsTagPoint)
        {
            TagPoint tp = cast(TagPoint)(mParentNode);
            return tp.getParentEntity().getParentSceneNode();
        }
        else
        {
            return cast(SceneNode)(mParentNode);
        }
    }
    
    /// Gets whether the parent node is a TagPoint (or a SceneNode)
    bool isParentTagPoint(){ return mParentIsTagPoint; }
    
    /** Internal method called to notify the object that it has been attached to a node.
    */
    void _notifyAttached(Node parent, bool isTagPoint = false)
    {
        assert(!mParentNode || !parent);
        
        bool different = (parent != mParentNode);
        
        mParentNode = parent;
        mParentIsTagPoint = isTagPoint;
        
        // Mark light list being dirty, simply decrease
        // counter by one for minimise overhead
        --mLightListUpdated;
        
        // Call listener (note, only called if there's something to do)
        if (mListener && different)
        {
            if (mParentNode)
                mListener.objectAttached(this);
            else
                mListener.objectDetached(this);
        }
    }
    
    /** Returns true if this object is attached to a SceneNode or TagPoint. */
    bool isAttached()
    {
        return (mParentNode !is null);
    }
    
    /** Detaches an object from a parent SceneNode or TagPoint, if attached. */
    void detachFromParent()
    {
        if (isAttached())
        {
            if (mParentIsTagPoint)
            {
                TagPoint tp = cast(TagPoint)(mParentNode);
                tp.getParentEntity().detachObjectFromBone(this);
            }
            else
            {
                SceneNode sn = cast(SceneNode)(mParentNode);
                sn.detachObject(this);
            }
        }
    }
    
    /** Returns true if this object is attached to a SceneNode or TagPoint, 
        and this SceneNode / TagPoint is currently in an active part of the
        scene graph. */
    bool isInScene()
    {
        if (mParentNode !is null)
        {
            if (mParentIsTagPoint)
            {
                TagPoint tp = cast(TagPoint)(mParentNode);
                return tp.getParentEntity().isInScene();
            }
            else
            {
                SceneNode sn = cast(SceneNode)(mParentNode);
                return sn.isInSceneGraph();
            }
        }
        else
        {
            return false;
        }
    }
    
    /** Internal method called to notify the object that it has been moved.
    */
    void _notifyMoved()
    {
        // Mark light list being dirty, simply decrease
        // counter by one for minimise overhead
        mLightListUpdated--;
        
        // Notify listener if exists
        if (mListener)
        {
            mListener.objectMoved(this);
        }
    }
    
    /** Internal method to notify the object of the camera to be used for the next rendering operation.
        @remarks
            Certain objects may want to do specific processing based on the camera position. This method notifies
            them in case they wish to do this.
    */
    void _notifyCurrentCamera(Camera cam)
    {
        if (mParentNode)
        {
            mBeyondFarDistance = false;
            
            if (cam.getUseRenderingDistance() && mUpperDistance > 0)
            {
                Real rad = getBoundingRadius();
                Real squaredDepth = mParentNode.getSquaredViewDepth(cam.getLodCamera());
                
               Vector3 scl = mParentNode._getDerivedScale();
                Real factor = std.math.fmax(std.math.fmax(scl.x, scl.y), scl.z);
                
                // Max distance to still render
                Real maxDist = mUpperDistance + rad * factor;
                if (squaredDepth > Math.Sqr(maxDist))
                {
                    mBeyondFarDistance = true;
                }
            }
            
            if (!mBeyondFarDistance && cam.getUseMinPixelSize() && mMinPixelSize > 0)
            {
                
                Real pixelRatio = cam.getPixelDisplayRatio();
                
                //if ratio is relative to distance than the distance at which the object should be displayed
                //is the size of the radius divided by the ratio
                //get the size of the entity in the world
                Vector3 objBound = getBoundingBox().getSize() * 
                    getParentNode()._getDerivedScale();
                
                //We object are projected from 3 dimensions to 2. The shortest displayed dimension of 
                //as object will always be at most the second largest dimension of the 3 dimensional
                //bounding box.
                //The square calculation come both to get rid of minus sign and for improve speed
                //in the final calculation
                objBound.x = Math.Sqr(objBound.x);
                objBound.y = Math.Sqr(objBound.y);
                objBound.z = Math.Sqr(objBound.z);
                float sqrObjMedianSize = std.math.fmax(std.math.fmax(
                    std.math.fmin(objBound.x,objBound.y),
                    std.math.fmin(objBound.x,objBound.z)),
                                                       std.math.fmin(objBound.y,objBound.z));
                
                //If we have a perspective camera calculations are done relative to distance
                Real sqrDistance = 1;
                if (cam.getProjectionType() == ProjectionType.PT_PERSPECTIVE)
                {
                    sqrDistance = mParentNode.getSquaredViewDepth(cam.getLodCamera());
                }
                
                //Final Calculation to tell whether the object is to small
                mBeyondFarDistance =  sqrObjMedianSize < 
                    sqrDistance * Math.Sqr(pixelRatio * mMinPixelSize); 
            }
            
            // Construct event object
            MovableObjectLodChangedEvent evt;
            evt.movableObject = this;
            evt.camera = cam;
            
            // Notify lod event listeners
            cam.getSceneManager()._notifyMovableObjectLodChanged(evt);
            
        }
        
        mRenderingDisabled = mListener && !mListener.objectRendering(this, cam);
    }
    
    /** Retrieves the local axis-aligned bounding box for this object.
        @remarks
            This bounding box is in local coordinates.
    */
    abstract AxisAlignedBox getBoundingBox();
    
    /** Retrieves the radius of the origin-centered bounding sphere 
         for this object.
    */
    abstract Real getBoundingRadius();
    
    /** Retrieves the axis-aligned bounding box for this object in world coordinates. */
    override AxisAlignedBox getWorldBoundingBox(bool derive = false)
    {
        if (derive)
        {
            mWorldAABB = this.getBoundingBox();
            mWorldAABB.transformAffine(_getParentNodeFullTransform());
        }
        
        return mWorldAABB;
        
    }
    
    /** Retrieves the worldspace bounding sphere for this object. */
    Sphere getWorldBoundingSphere(bool derive = false) //const
    {
        if (derive)
        {
           Vector3 scl = mParentNode._getDerivedScale();
            Real factor = std.math.fmax(std.math.fmax(scl.x, scl.y), scl.z);
            mWorldBoundingSphere.setRadius(getBoundingRadius() * factor);
            mWorldBoundingSphere.setCenter(mParentNode._getDerivedPosition());
        }
        return mWorldBoundingSphere;
    }
    
    /** Internal method by which the movable object must add Renderable subclass instances to the rendering queue.
        @remarks
            The engine will call this method when this object is to be rendered. The object must then create one or more
            Renderable subclass instances which it places on the passed in Queue for rendering.
    */
    abstract void _updateRenderQueue(RenderQueue queue);
    
    /** Tells this object whether to be visible or not, if it has a renderable component. 
    @note An alternative approach of making an object invisible is to detach it
        from it's SceneNode, or to remove the SceneNode entirely. 
        Detaching a node means that structurally the scene graph changes. 
        Once this change has taken place, the objects / nodes that have been 
        removed have less overhead to the visibility detection pass than simply
        making the object invisible, so if you do this and leave the objects 
        out of the tree for a long time, it's faster. However, the act of 
        detaching / reattaching nodes is in itself more expensive than 
        setting an object visibility flag, since in the latter case 
        structural changes are not made. Therefore, small or frequent visibility
        changes are best done using this method; large or more longer term
        changes are best done by detaching.
    */
    void setVisible(bool visible)
    {
        mVisible = visible;
    }
    
    /** Gets this object whether to be visible or not, if it has a renderable component. 
    @remarks
        Returns the value set by MovableObject.setVisible only.
    */
    bool getVisible()
    {
        return mVisible;
    }
    
    /** Returns whether or not this object is supposed to be visible or not. 
    @remarks
        Takes into account both upper rendering distance and visible flag.
    */
    bool isVisible()
    {
        if (!mVisible || mBeyondFarDistance || mRenderingDisabled)
            return false;
        
        SceneManager sm = Root.getSingleton()._getCurrentSceneManager();
        if (sm && !(getVisibilityFlags() & sm._getCombinedVisibilityMask()))
            return false;
        
        return true;
    }
    
    /** Sets the distance at which the object is no longer rendered.
    @note Camera.setUseRenderingDistance() needs to be called for this parameter to be used.
    @param dist Distance beyond which the object will not be rendered 
        (the default is 0, which means objects are always rendered).
    */
    void setRenderingDistance(Real dist) { 
        mUpperDistance = dist; 
        mSquaredUpperDistance = mUpperDistance * mUpperDistance;
    }
    
    /** Gets the distance at which batches are no longer rendered. */
    Real getRenderingDistance(){ return mUpperDistance; }        
    
    /** Sets the minimum pixel size an object needs to be in both screen axes in order to be rendered
    @note Camera.setUseMinPixelSize() needs to be called for this parameter to be used.
    @param pixelSize Number of minimum pixels
        (the default is 0, which means objects are always rendered).
    */
    void setRenderingMinPixelSize(Real pixelSize) { 
        mMinPixelSize = pixelSize; 
    }
    
    /** Returns the minimum pixel size an object needs to be in both screen axes in order to be rendered
    */
    Real getRenderingMinPixelSize(){ 
        return mMinPixelSize; 
    }
    
    /** @deprecated use UserObjectBindings.setUserAny via getUserObjectBindings() instead.
        Sets any kind of user value on this object.
    @remarks
        This method allows you to associate any user value you like with 
        this MovableObject. This can be a pointer back to one of your own
        classes for instance.       
    */
    //void setUserAny(Any anything) { getUserObjectBindings().setUserAny(anything); }
    
    /** @deprecated use UserObjectBindings.getUserAny via getUserObjectBindings() instead.
        Retrieves the custom user value associated with this object.
    */
   //ref Any getUserAny(){ return getUserObjectBindings().getUserAny(); }
    
    /** Return an instance of user objects binding associated with this class.
    You can use it to associate one or more custom objects with this class instance.
    @see UserObjectBindings.setUserAny.        
    */
    //ref UserObjectBindings getUserObjectBindings() { return mUserObjectBindings; }

    /** Sets the render queue group this entity will be rendered through.
    @remarks
        Render queues are grouped to allow you to more tightly control the ordering
        of rendered objects. If you do not call this method, all Entity objects default
        to the default queue (RenderQueue.getDefaultQueueGroup), which is fine for most objects. You may want to alter this
        if you want this entity to always appear in front of other objects, e.g. for
        a 3D menu system or such.
    @par
        See RenderQueue for more details.
    @param queueID Enumerated value of the queue group to use. See the
        enum RenderQueueGroupID for what kind of values can be used here.
    */
    void setRenderQueueGroup(ubyte queueID)
    {
        assert(queueID <= RenderQueueGroupID.RENDER_QUEUE_MAX, "Render queue out of range!");
        mRenderQueueID = queueID;
        mRenderQueueIDSet = true;
    }
    
    /** Sets the render queue group and group priority this entity will be rendered through.
    @remarks
        Render queues are grouped to allow you to more tightly control the ordering
        of rendered objects. Within a single render group there another type of grouping
        called priority which allows further control.  If you do not call this method, 
        all Entity objects default to the default queue and priority 
        (RenderQueue.getDefaultQueueGroup, RenderQueue.getDefaultRenderablePriority), 
        which is fine for most objects. You may want to alter this if you want this entity 
        to always appear in front of other objects, e.g. for a 3D menu system or such.
    @par
        See RenderQueue for more details.
    @param queueID Enumerated value of the queue group to use. See the
        enum RenderQueueGroupID for what kind of values can be used here.
    @param priority The priority within a group to use.
    */
    void setRenderQueueGroupAndPriority(ubyte queueID, ushort priority)
    {
        setRenderQueueGroup(queueID);
        mRenderQueuePriority = priority;
        mRenderQueuePrioritySet = true;
        
    }
    
    /** Gets the queue group for this entity, see setRenderQueueGroup for full details. */
    ubyte getRenderQueueGroup()
    {
        return mRenderQueueID;
    }
    
    /// return the full transformation of the parent sceneNode or the attachingPoint node
    Matrix4 _getParentNodeFullTransform()
    {
        
        if(mParentNode)
        {
            // object attached to a sceneNode
            return mParentNode._getFullTransform();
        }
        // fallback
        return Matrix4.IDENTITY;
    }
    
    /** Sets the query flags for this object.
    @remarks
        When performing a scene query, this object will be included or excluded according
        to flags on the object and flags on the query. This is a bitwise value, so only when
        a bit on these flags is set, will it be included in a query asking for that flag. The
        meaning of the bits is application-specific.
    */
    void setQueryFlags(uint flags) { mQueryFlags = flags; }
    
    /** As setQueryFlags, except the flags passed as parameters are appended to the
    existing flags on this object. */
    void addQueryFlags(uint flags) { mQueryFlags |= flags; }
    
    /** As setQueryFlags, except the flags passed as parameters are removed from the
    existing flags on this object. */
    void removeQueryFlags(uint flags) { mQueryFlags &= ~flags; }
    
    /// Returns the query flags relevant for this object
    uint getQueryFlags(){ return mQueryFlags; }
    
    /** Set the default query flags for all future MovableObject instances.
    */
    static void setDefaultQueryFlags(uint flags) { msDefaultQueryFlags = flags; }
    
    /** Get the default query flags for all future MovableObject instances.
    */
    static uint getDefaultQueryFlags() { return msDefaultQueryFlags; }
    
    
    /** Sets the visiblity flags for this object.
    @remarks
        As well as a simple true/false value for visibility (as seen in setVisible), 
        you can also set visiblity flags which when 'and'ed with the SceneManager's
        visibility mask can also make an object invisible.
    */
    void setVisibilityFlags(uint flags) { mVisibilityFlags = flags; }
    
    /** As setVisibilityFlags, except the flags passed as parameters are appended to the
    existing flags on this object. */
    void addVisibilityFlags(uint flags) { mVisibilityFlags |= flags; }
    
    /** As setVisibilityFlags, except the flags passed as parameters are removed from the
    existing flags on this object. */
    void removeVisibilityFlags(uint flags) { mVisibilityFlags &= ~flags; }
    
    /// Returns the visibility flags relevant for this object
    uint getVisibilityFlags(){ return mVisibilityFlags; }
    
    /** Set the default visibility flags for all future MovableObject instances.
    */
    static void setDefaultVisibilityFlags(uint flags) { msDefaultVisibilityFlags = flags; }
    
    /** Get the default visibility flags for all future MovableObject instances.
    */
    static uint getDefaultVisibilityFlags() { return msDefaultVisibilityFlags; }
    
    /** Sets a listener for this object.
    @remarks
        Note for size and performance reasons only one listener per object
        is allowed.
    */
    void setListener(Listener listener) { mListener = listener; }
    
    /** Gets the current listener for this object.
    */
    Listener getListener(){ return mListener; }
    
    /** Gets a list of lights, ordered relative to how close they are to this movable object.
    @remarks
        By default, this method gives the listener a chance to populate light list first,
        if there is no listener or Listener.objectQueryLights returns null, it'll
        query the light list from parent entity if it is present, or returns
        SceneNode.findLights if it has parent scene node, otherwise it just returns
        an empty list.
    @par
        The object internally caches the light list, so it will recalculate
        it only when object is moved, or lights that affect the frustum have
        been changed (@see SceneManager._getLightsDirtyCounter),
        but if listener exists, it will be called each time, so the listener 
        should implement their own cache mechanism to optimise performance.
    @par
        This method can be useful when implementing Renderable.getLights in case
        the renderable is a part of the movable.
    @return The list of lights use to lighting this object.
    */
    LightList queryLights() //const
    {
        // Try listener first
        if (mListener)
        {
           LightList *lightList =
                mListener.objectQueryLights(this);
            if (lightList)
            {
                return *lightList;
            }
        }
        
        // Query from parent entity if exists
        if (mParentIsTagPoint)
        {
            TagPoint tp = cast(TagPoint)(mParentNode);
            return tp.getParentEntity().queryLights();
        }
        
        if (mParentNode)
        {
            SceneNode sn = cast(SceneNode)(mParentNode);
            
            // Make sure we only update this only if need.
            ulong frame = sn.getCreator()._getLightsDirtyCounter();
            if (mLightListUpdated != frame)
            {
                mLightListUpdated = frame;
                
               Vector3 scl = mParentNode._getDerivedScale();
                Real factor = std.math.fmax(std.math.fmax(scl.x, scl.y), scl.z);
                
                sn.findLights(mLightList, this.getBoundingRadius() * factor, this.getLightMask());
            }
        }
        else
        {
            mLightList.clear();
        }
        
        return mLightList;
    }
    
    /** Get a bitwise mask which will filter the lights affecting this object
    @remarks
    By default, this mask is fully set meaning all lights will affect this object
    */
    uint getLightMask(){ return mLightMask; }
    /** Set a bitwise mask which will filter the lights affecting this object
    @remarks
    This mask will be compared against the mask held against Light to determine
    if a light should affect a given object. 
    By default, this mask is fully set meaning all lights will affect this object
    */
    void setLightMask(uint lightMask)
    {
        this.mLightMask = lightMask;
        //make sure to request a new light list from the scene manager if mask changed
        mLightListUpdated = 0;
    }
    
    /** Returns a pointer to the current list of lights for this object.
    @remarks
        You should not modify this list outside of MovableObject.Listener.objectQueryLights
        (say if you want to use it to implement this method, and use the pointer
        as a return value) and for reading it's only accurate as at the last frame.
    */
    LightList _getLightList() { return mLightList; }
    
    /// Define a default implementation of method from ShadowCaster which implements no shadows
    override EdgeData getEdgeList() { return null; }
    /// Define a default implementation of method from ShadowCaster which implements no shadows
    override bool hasEdgeList() { return false; }
    /// Define a default implementation of method from ShadowCaster which implements no shadows
    /*ShadowRenderableListIterator getShadowVolumeRenderableIterator(
        ShadowTechnique shadowTechnique,Light* light, 
        SharedPtr!HardwareIndexBuffer* indexBuffer, 
        bool extrudeVertices, Real extrusionDist, ulong flags = 0)
    {
        static ShadowRenderableList dummyList;
        return ShadowRenderableListIterator(dummyList.begin(), dummyList.end());
    }*/

    override ShadowRenderableList getShadowVolumeRenderables(
        ShadowTechnique shadowTechnique, ref Light light, 
        SharedPtr!HardwareIndexBuffer* indexBuffer, 
        bool _extrudeVertices, Real extrusionDistance, ulong flags = 0 )
    {
        static ShadowRenderableList dummyList;
        return dummyList;
    }
    
    /** Overridden member from ShadowCaster. */
    override AxisAlignedBox getLightCapBounds()
    {
        // Same as original bounds
        return getWorldBoundingBox();
    }
    /** Overridden member from ShadowCaster. */
    override AxisAlignedBox getDarkCapBounds(Light light, Real dirLightExtrusionDist)
    {
        // Extrude own light cap bounds
        mWorldDarkCapBounds = getLightCapBounds();
        this.extrudeBounds(mWorldDarkCapBounds, light.getAs4DVector(), 
                           dirLightExtrusionDist);
        return mWorldDarkCapBounds;
        
    }
    /** Sets whether or not this object will cast shadows.
    @remarks
    This setting simply allows you to turn on/off shadows for a given object.
    An object will not cast shadows unless the scene supports it in any case
    (see SceneManager.setShadowTechnique), and also the material which is
    in use must also have shadow casting enabled. By default all entities cast
    shadows. If, however, for some reason you wish to disable this for a single 
    object then you can do so using this method.
    @note This method normally refers to objects which block the light, but
    since Light is also a subclass of MovableObject, in that context it means
    whether the light causes shadows itself.
    */
    void setCastShadows(bool enabled) { mCastShadows = enabled; }
    /** Returns whether shadow casting is enabled for this object. */
    override bool getCastShadows(){ return mCastShadows; }
    /** Returns whether the Material of any Renderable that this MovableObject will add to 
        the render queue will receive shadows. 
    */
    bool getReceivesShadows()
    {
        auto visitor = new MORecvShadVisitor;
        visitRenderables(visitor);
        return visitor.anyReceiveShadows;
        
    }
    
    /** Get the distance to extrude for a point/spot light */
    override Real getPointExtrusionDistance(ref Light l) //const
    {
        if (mParentNode)
        {
            return getExtrusionDistance(mParentNode._getDerivedPosition(), l);
        }
        else
        {
            return 0;
        }
    }
    /** Get the 'type flags' for this MovableObject.
    @remarks
        A type flag identifies the type of the MovableObject as a bitpattern. 
        This is used for categorical inclusion / exclusion in SceneQuery
        objects. By default, this method returns all ones for objects not 
        created by a MovableObjectFactory (hence always including them); 
        otherwise it returns the value assigned to the MovableObjectFactory.
        Custom objects which don't use MovableObjectFactory will need to 
        override this if they want to be included in queries.
    */
    uint getTypeFlags()
    {
        if (mCreator)
        {
            return cast(uint)mCreator.getTypeFlags();
        }
        else
        {
            return 0xFFFFFFFF;
        }
    }
    
    /** Method to allow a caller to abstractly iterate over the Renderable
        instances that this MovableObject will add to the render queue when
        asked, if any. 
    @param visitor Pointer to a class implementing the Renderable.Visitor 
        interface which will be called back for each Renderable which will
        be queued. Bear in mind that the state of the Renderable instances
        may not be finalised depending on when you call this.
    @param debugRenderables If false, only regular renderables will be visited
        (those for normal display). If true, debug renderables will be
        included too.
    */
    abstract void visitRenderables(Renderable.Visitor visitor, 
                                   bool debugRenderables = false);
    
    /** Sets whether or not the debug display of this object is enabled.
    @remarks
        Some objects aren't visible themselves but it can be useful to display
        a debug representation of them. Or, objects may have an additional 
        debug display on top of their regular display. This option enables / 
        disables that debug display. Objects that are not visible never display
        debug geometry regardless of this setting.
    */
    void setDebugDisplayEnabled(bool enabled) { mDebugDisplay = enabled; }
    /// Gets whether debug display of this object is enabled. 
    bool isDebugDisplayEnabled(){ return mDebugDisplay; }
    
    
    
    
    
}

/** Interface definition for a factory class which produces a certain
    kind of MovableObject, and can be registered with Root in order
    to allow all clients to produce new instances of this object, integrated
    with the standard Ogre processing.
*/
class MovableObjectFactory //: public MovableAlloc
{
protected:
    /// Type flag, allocated if requested
    ulong mTypeFlag;
    
    /// Internal implementation of create method - must be overridden
    abstract MovableObject createInstanceImpl(
       string name, NameValuePairList params = null);
public:
    this() { mTypeFlag = 0xFFFFFFFF; }
    ~this() {}
    /// Get the type of the object to be created
    abstract string getType();
    
    /** Create a new instance of the object.
    @param name The name of the new object
    @param manager The SceneManager instance that will be holding the
        instance once created.
    @param params Name/value pair list of additional parameters required to 
        construct the object (defined per subtype). Optional.
    */
    MovableObject createInstance(
       string name, SceneManager manager, 
       NameValuePairList params = null)
    {
        MovableObject m = createInstanceImpl(name, params);
        m._notifyCreator(this);
        m._notifyManager(manager);
        return m;
    }
    
    /** Destroy an instance of the object */
    abstract void destroyInstance(ref MovableObject obj);
    
    /** Does this factory require the allocation of a 'type flag', used to 
        selectively include / exclude this type from scene queries?
    @remarks
        The default implementation here is to return 'false', ie not to 
        request a unique type mask from Root. For objects that
        never need to be excluded in SceneQuery results, that's fine, since
        the default implementation of MovableObject.getTypeFlags is to return
        all ones, hence matching any query type mask. However, if you want the
        objects created by this factory to be filterable by queries using a 
        broad type, you have to give them a (preferably unique) type mask - 
        and given that you don't know what other MovableObject types are 
        registered, Root will allocate you one. 
    */
    bool requestTypeFlags(){ return false; }
    /** Notify this factory of the type mask to apply. 
    @remarks
        This should normally only be called by Root in response to
        a 'true' result from requestTypeMask. However, you can actually use
        it yourself if you're careful; for example to assign the same mask
        to a number of different types of object, should you always wish them
        to be treated the same in queries.
    */
    void _notifyTypeFlags(ulong flag) { mTypeFlag = flag; }
    
    /** Gets the type flag for this factory.
    @remarks
        A type flag is like a query flag, except that it applies to all instances
        of a certain type of object.
    */
    ulong getTypeFlags(){ return mTypeFlag; }
    
}


class MORecvShadVisitor : Renderable.Visitor
{
public:
    bool anyReceiveShadows = false;
    this() {}
    override void visit(Renderable rend, ushort lodIndex, bool isDebug, 
               Any pAny /*= null*/)
    {
        Technique tech = rend.getTechnique();
        bool techReceivesShadows = tech && tech.getParent().getReceiveShadows();
        anyReceiveShadows = anyReceiveShadows || 
            techReceivesShadows || !tech;
    }
}
