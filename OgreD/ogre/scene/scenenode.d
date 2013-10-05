module ogre.scene.scenenode;


import ogre.compat;
import ogre.math.axisalignedbox;
import ogre.math.vector;
import ogre.math.quaternion;
import ogre.math.angles;
import ogre.general.common;
import ogre.scene.node;
import ogre.scene.movableobject;
import ogre.scene.wireboundingbox;
import ogre.scene.scenemanager;
import ogre.scene.camera;
import ogre.rendersystem.renderqueue;
import ogre.exception;
import ogre.sharedptr;

/** \addtogroup Core
 *  @{
 */
/** \addtogroup Scene
 *  @{
 */
/** Class representing a node in the scene graph.
 @remarks
 A SceneNode is a type of Node which is used to organise objects in a scene.
 It has the same hierarchical transformation properties of the generic Node class,
 but also adds the ability to attach world objects to the node, and stores hierarchical
 bounding volumes of the nodes in the tree.
 Child nodes are contained within the bounds of the parent, and so on down the
 tree, allowing for fast culling.
 */
class SceneNode : Node
{
public:
    //typedef HashMap<String, MovableObject*> ObjectMap;
    //typedef MapIterator<ObjectMap> ObjectIterator;
    //typedef ConstMapIterator<ObjectMap> ConstObjectIterator;
    
    //alias MovableObject[string] ObjectMap;

protected:
    MovableObject[string] mObjectsByName;
    
    /// Pointer to a Wire Bounding Box for this Node
    WireBoundingBox mWireBoundingBox;
    /// Flag that determines if the bounding box of the node should be displayed
    bool mShowBoundingBox;
    bool mHideBoundingBox;
    
    /// SceneManager which created this node
    SceneManager mCreator;
    
    /// World-Axis aligned bounding box, updated only through _update
    AxisAlignedBox mWorldAABB;
    
    /** @copydoc Node::updateFromParentImpl. */
    override void updateFromParentImpl()//
    {
        super.updateFromParentImpl();
        
        // Notify objects that it has been moved
        foreach (k,v; mObjectsByName)
        {
            v._notifyMoved();
        }
    }
    
    /** See Node. */
    override Node createChildImpl()
    {
        assert(mCreator);
        return mCreator.createSceneNode();
    }
    
    /** See Node. */
    override Node createChildImpl(string name)
    {
        assert(mCreator);
        return mCreator.createSceneNode(name);
    }
    
    /** See Node */
    override void setParent(Node parent)
    {
        super.setParent(parent);
        
        if (parent)
        {
            SceneNode sceneParent = cast(SceneNode)(parent);
            setInSceneGraph(sceneParent.isInSceneGraph());
        }
        else
        {
            setInSceneGraph(false);
        }
    }
    
    
    /** Internal method for setting whether the node is in the scene 
     graph.
     */
    void setInSceneGraph(bool inGraph)
    {
        if (inGraph != mIsInSceneGraph)
        {
            mIsInSceneGraph = inGraph;
            // Tell children
            foreach (k,v; mChildren)
            {
                SceneNode sceneChild = cast(SceneNode)(v);
                sceneChild.setInSceneGraph(inGraph);
            }
        }
    }
    
    /// Whether to yaw around a fixed axis.
    bool mYawFixed;
    /// Fixed axis to yaw around
    Vector3 mYawFixedAxis;
    
    /// Auto tracking target
    SceneNode mAutoTrackTarget;
    /// Tracking offset for fine tuning
    Vector3 mAutoTrackOffset;
    /// Local 'normal' direction vector
    Vector3 mAutoTrackLocalDirection;
    /// Is this node a current part of the scene graph?
    bool mIsInSceneGraph;
public:

    ///FIXME How the heck does "SceneNode node;" in c++ work without this()?
    /*this()
    {
        super();
    }*/

    /** Constructor, only to be called by the creator SceneManager.
     @remarks
     Creates a node with a generated name.
     */
    this(SceneManager creator)
    {
        mWireBoundingBox = null;
        mShowBoundingBox = false;
        mHideBoundingBox = false;
        mCreator = creator;
        mYawFixed = false;
        mAutoTrackTarget = null;
        mIsInSceneGraph = false;
        needUpdate();
    }
    /** Constructor, only to be called by the creator SceneManager.
     @remarks
     Creates a node with a specified name.
     */
    this(ref SceneManager creator,string name)
    {
        super(name);
        mWireBoundingBox = null;
        mShowBoundingBox = false;
        mHideBoundingBox = false;
        mCreator = creator;
        mYawFixed = false;
        mAutoTrackTarget = null;
        mIsInSceneGraph = false;
        needUpdate();
    }
    
    ~this()
    {
        // Detach all objects, do this manually to avoid needUpdate() call 
        // which can fail because of deleted items
        foreach (k,v; mObjectsByName)
        {
            v._notifyAttached(null);
        }
        mObjectsByName.clear();
        
        if (mWireBoundingBox) {
            destroy(mWireBoundingBox);
        }
    }
    
    /** Adds an instance of a scene object to this node.
     @remarks
     Scene objects can include Entity objects, Camera objects, Light objects, 
     ParticleSystem objects etc. Anything that subclasses from MovableObject.
     */
    void attachObject(/*ref*/ MovableObject obj)
    {
        if (obj.isAttached())
        {
            throw new InvalidParamsError(
                "Object already attached to a SceneNode or a Bone",
                "SceneNode::attachObject");
        }
        
        obj._notifyAttached(this);
        
        auto ptr = obj.getName() in mObjectsByName;
        
        assert(ptr is null , "Object was not attached because an object of the " ~
               "same name was already attached to this node.");

        // Also add to name index
        mObjectsByName[obj.getName()] = obj;
        // Make sure bounds get updated (must go right to the top)
        needUpdate();
    }
    
    /** Reports the number of objects attached to this node.
     */
    ushort numAttachedObjects()
    {
        return cast(ushort)( mObjectsByName.lengthAA );
    }
    
    /** Retrieves a pointer to an attached object.
     @remarks Retrieves by index, see alternate version to retrieve by name. The index
     of an object may change as other objects are added / removed.
     */
    MovableObject getAttachedObject(ushort index)
    {
        if (index < mObjectsByName.lengthAA)
        {
            return mObjectsByName[keysAA(mObjectsByName)[index]];
        }
        else
        {
            throw new InvalidParamsError( "Object index out of bounds.", "SceneNode::getAttachedObject");
        }
    }
    
    /** Retrieves a pointer to an attached object.
     @remarks Retrieves by object name, see alternate version to retrieve by index.
     */
    MovableObject getAttachedObject(string name)
    {
        // Look up 
        auto i = name in mObjectsByName;
        
        if (i is null)
        {
            throw new ItemNotFoundError( "Attached object " ~ 
                                        name ~ " not found.", "SceneNode::getAttachedObject");
        }
        
        return *i;
        
    }
    
    /** Detaches the indexed object from this scene node.
     @remarks
     Detaches by index, see the alternate version to detach by name. Object indexes
     may change as other objects are added / removed.
     */
    MovableObject detachObject(ushort index)
    {
        if (index < mObjectsByName.lengthAA)
        {
            
            /*foreach(k,v; mObjectsByName)
             {
             ret = v;
             index--;
             if(index<0) break;
             }*/
            assert(0);
            return null;
            /*auto key = mObjectsByName.keys[index];
            MovableObject ret = mObjectsByName[key];
            mObjectsByName.remove(key);
            ret._notifyAttached(null);
            
            // Make sure bounds get updated (must go right to the top)
            needUpdate();
            
            return ret;*/
            
        }
        else
        {
            throw new InvalidParamsError("Object index out of bounds.", "SceneNode::getAttchedEntity");
        }
        
    }
    /** Detaches an object by pointer. */
    void detachObject(MovableObject obj)
    {
        foreach (k,v; mObjectsByName)
        {
            if (v == obj)
            {
                mObjectsByName.remove(k);
                break;
            }
        }
        obj._notifyAttached(null);
        
        // Make sure bounds get updated (must go right to the top)
        needUpdate();
        
    }
    
    /** Detaches the named object from this node and returns a pointer to it. */
    MovableObject detachObject(string name)
    {
        auto it = name in mObjectsByName;
        if (it is null)
        {
            throw new ItemNotFoundError( "Object " ~ name ~ " is not attached to this node.", 
                                        "SceneNode::detachObject");
        }
        MovableObject ret = *it;
        mObjectsByName.remove(name);
        ret._notifyAttached(null);
        // Make sure bounds get updated (must go right to the top)
        needUpdate();
        
        return ret;
        
    }
    
    /** Detaches all objects attached to this node.
     */
    void detachAllObjects()
    {
        foreach (k,v; mObjectsByName)
        {
            v._notifyAttached(null);
        }
        mObjectsByName.clear();
        // Make sure bounds get updated (must go right to the top)
        needUpdate();
    }
    
    /** Determines whether this node is in the scene graph, i.e.
     whether it's ultimate ancestor is the root scene node.
     */
    bool isInSceneGraph(){ return mIsInSceneGraph; }
    
    /** Notifies this SceneNode that it is the root scene node. 
     @remarks
     Only SceneManager should call this!
     */
    void _notifyRootNode() { mIsInSceneGraph = true; }
    
    
    /** Internal method to update the Node.
     @note
     Updates this scene node and any relevant children to incorporate transforms etc.
     Don't call this yourself unless you are writing a SceneManager implementation.
     @param
     updateChildren If true, the update cascades down to all children. Specify false if you wish to
     update children separately, e.g. because of a more selective SceneManager implementation.
     @param
     parentHasChanged This flag indicates that the parent transform has changed,
     so the child should retrieve the parent's transform and combine it with its own
     even if it hasn't changed itself.
     */
    override void _update(bool updateChildren, bool parentHasChanged)
    {
        super._update(updateChildren, parentHasChanged);
        _updateBounds();
    }
    
    /** Tells the SceneNode to update the world bound info it stores.
     */
    void _updateBounds()
    {
        // Reset bounds first
        mWorldAABB.setNull();
        
        // Update bounds from own attached objects
        foreach (k,v; mObjectsByName)
        {
            // Merge world bounds of each object
            mWorldAABB.merge(v.getWorldBoundingBox(true));
        }
        
        // Merge with children
        foreach (k,v; mChildren)
        {
            SceneNode sceneChild = cast(SceneNode)(v);
            mWorldAABB.merge(sceneChild.mWorldAABB);
        }
        
    }
    
    /** Internal method which locates any visible objects attached to this node and adds them to the passed in queue.
     @remarks
     Should only be called by a SceneManager implementation, and only after the _updat method has been called to
     ensure transforms and world bounds are up to date.
     SceneManager implementations can choose to let the search cascade automatically, or choose to prevent this
     and select nodes themselves based on some other criteria.
     @param
     cam The active camera
     @param
     queue The SceneManager's rendering queue
     @param
     visibleBounds bounding information created on the fly containing all visible objects by the camera
     @param
     includeChildren If true, the call is cascaded down to all child nodes automatically.
     @param
     displayNodes If true, the nodes themselves are rendered as a set of 3 axes as well
     as the objects being rendered. For debugging purposes.
     */
    void _findVisibleObjects(Camera cam, RenderQueue queue, 
                             VisibleObjectsBoundsInfo visibleBounds, 
                             bool includeChildren = true, bool displayNodes = false, bool onlyShadowCasters = false)
    {
        debug(STDERR) std.stdio.stderr.writeln("SceneNode._findVisibleObjects: ", mName , ",", 
                                       mWorldAABB, " Vis:",cam.isVisible(mWorldAABB, null));
        // Check self visible
        if (!cam.isVisible(mWorldAABB, null))
            return;
        
        // Add all entities
        foreach (k,v; mObjectsByName)
        {
            debug(STDERR) std.stdio.stderr.writeln("\t", k,"=",v);
            queue.processVisibleObject(v, cam, onlyShadowCasters, visibleBounds);
        }
        
        if (includeChildren)
        {
            debug(STDERR) std.stdio.stderr.writeln("SceneNode._findVisibleObjects children:");
            foreach (k,v; mChildren)
            {
                SceneNode sceneChild = cast(SceneNode)(v);
                debug(STDERR) std.stdio.stderr.writeln("\tChild:", sceneChild.mName);
                sceneChild._findVisibleObjects(cam, queue, visibleBounds, includeChildren, 
                                               displayNodes, onlyShadowCasters);
            }
        }
        
        if (displayNodes)
        {
            // Include self in the render queue
            auto dbg = getDebugRenderable();
            queue.addRenderable(dbg);
        }
        
        // Check if the bounding box should be shown.
        // See if our flag is set or if the scene manager flag is set.
        if ( !mHideBoundingBox &&
            (mShowBoundingBox || (mCreator && mCreator.getShowBoundingBoxes())) )
        { 
            _addBoundingBoxToQueue(queue);
        }
        
        
    }
    
    /** Gets the axis-aligned bounding box of this node (and hence all subnodes).
     @remarks
     Recommended only if you are extending a SceneManager, because the bounding box returned
     from this method is only up to date after the SceneManager has called _update.
     */
    AxisAlignedBox _getWorldAABB()
    {
        return mWorldAABB;
    }
    
    /** Retrieves an iterator which can be used to efficiently step through the objects 
     attached to this node.
     @remarks
     This is a much faster way to go through <B>all</B> the objects attached to the node
     than using getAttachedObject. But the iterator returned is only valid until a change
     is made to the collection (ie an addition or removal) so treat the returned iterator
     as transient, and don't add / remove items as you go through the iterator, save changes
     until the end, or retrieve a new iterator after making the change. Making changes to
     the object returned through the iterator is OK though.
     */
    //ObjectIterator getAttachedObjectIterator();
    MovableObject[string] getAttachedObjects()
    {
        return mObjectsByName;
    }
    /** Retrieves an iterator which can be used to efficiently step through the objects 
     attached to this node.
     @remarks
     This is a much faster way to go through <B>all</B> the objects attached to the node
     than using getAttachedObject. But the iterator returned is only valid until a change
     is made to the collection (ie an addition or removal) so treat the returned iterator
     as transient, and don't add / remove items as you go through the iterator, save changes
     until the end, or retrieve a new iterator after making the change. Making changes to
     the object returned through the iterator is OK though.
     */
    //ConstObjectIterator getAttachedObjectIterator();
    
    /** Gets the creator of this scene node. 
     @remarks
     This method returns the SceneManager which created this node.
     This can be useful for destroying this node.
     */
    ref SceneManager getCreator(){ return mCreator; }
    
    /** This method removes and destroys the named child and all of its children.
     @remarks
     Unlike removeChild, which removes a single named child from this
     node but does not destroy it, this method destroys the child
     and all of it's children. 
     @par
     Use this if you wish to recursively destroy a node as well as 
     detaching it from it's parent. Note that any objects attached to
     the nodes will be detached but will not themselves be destroyed.
     */
    void removeAndDestroyChild(string name)
    {
        SceneNode pChild = cast(SceneNode)(getChild(name));
        pChild.removeAndDestroyAllChildren();
        
        removeChild(name);
        pChild.getCreator().destroySceneNode(name);
        
    }
    
    /** This method removes and destroys the child and all of its children.
     @remarks
     Unlike removeChild, which removes a single named child from this
     node but does not destroy it, this method destroys the child
     and all of it's children. 
     @par
     Use this if you wish to recursively destroy a node as well as 
     detaching it from it's parent. Note that any objects attached to
     the nodes will be detached but will not themselves be destroyed.
     */
    void removeAndDestroyChild(ushort index)
    {
        SceneNode pChild = cast(SceneNode)(getChild(index));
        pChild.removeAndDestroyAllChildren();
        
        removeChild(index);
        pChild.getCreator().destroySceneNode(pChild.getName());
    }
    
    /** Removes and destroys all children of this node.
     @remarks
     Use this to destroy all child nodes of this node and remove
     them from the scene graph. Note that all objects attached to this
     node will be detached but will not be destroyed.
     */
    void removeAndDestroyAllChildren()
    {
        foreach (k,v; mChildren)
        {
            SceneNode sn = cast(SceneNode)(v);
            sn.removeAndDestroyAllChildren();
            sn.getCreator().destroySceneNode(sn.getName());
        }
        mChildren.clear();
        needUpdate();
    }
    
    /** Allows the showing of the node's bounding box.
     @remarks
     Use this to show or hide the bounding box of the node.
     */
    void showBoundingBox(bool bShow)
    {
        mShowBoundingBox = bShow;
    }
    
    /** Allows the overriding of the node's bounding box
     over the SceneManager's bounding box setting.
     @remarks
     Use this to override the bounding box setting of the node.
     */
    void hideBoundingBox(bool bHide)
    {
        mHideBoundingBox = bHide;
    }
    
    /** Add the bounding box to the rendering queue.
     */
    void _addBoundingBoxToQueue(ref RenderQueue queue) 
    {
        // Create a WireBoundingBox if needed.
        if (mWireBoundingBox is null) {
            mWireBoundingBox = new WireBoundingBox();
        }
        mWireBoundingBox.setupBoundingBox(mWorldAABB);
        queue.addRenderable(mWireBoundingBox);
    }
    
    /** This allows scene managers to determine if the node's bounding box
     should be added to the rendering queue.
     @remarks
     Scene Managers that implement their own _findVisibleObjects will have to 
     check this flag and then use _addBoundingBoxToQueue to add the bounding box
     wiref rame.
     */
    bool getShowBoundingBox()
    {
        return mShowBoundingBox;
    }
    
    /** Creates an unnamed new SceneNode as a child of this node.
     @param
     translate Initial translation offset of child relative to parent
     @param
     rotate Initial rotation relative to parent
     */
    SceneNode createChildSceneNode(
       Vector3 translate = Vector3.ZERO, 
       Quaternion rotate = Quaternion.IDENTITY )
    {
        return cast(SceneNode)(this.createChild(translate, rotate));
    }
    
    /** Creates a new named SceneNode as a child of this node.
     @remarks
     This creates a child node with a given name, which allows you to look the node up from 
     the parent which holds this collection of nodes.
     @param
     translate Initial translation offset of child relative to parent
     @param
     rotate Initial rotation relative to parent
     */
    SceneNode createChildSceneNode(string name,Vector3 translate = Vector3.ZERO, 
                                      Quaternion rotate = Quaternion.IDENTITY)
    {
        return cast(SceneNode)(this.createChild(name, translate, rotate));
    }
    
    /** Allows retrieval of the nearest lights to the centre of this SceneNode.
     @remarks
     This method allows a list of lights, ordered by proximity to the centre
     of this SceneNode, to be retrieved. Can be useful when implementing
     MovableObject::queryLights and Renderable::getLights.
     @par
     Note that only lights could be affecting the frustum will take into
     account, which cached in scene manager.
     @see SceneManager::_getLightsAffectingFrustum
     @see SceneManager::_populateLightList
     @param destList List to be populated with ordered set of lights; will be
     cleared by this method before population.
     @param radius Parameter to specify lights intersecting a given radius of
     this SceneNode's centre.
     @param lightMask The mask with which to include / exclude lights
     */
    void findLights(ref LightList destList, Real radius, uint lightMask = 0xFFFFFFFF)//
    {
        // No any optimisation here, hope inherits more smart for that.
        //
        // If a scene node is static and lights have moved, light list won't change
        // can't use a simple global boolean flag since this is only called for
        // visible nodes, so temporarily visible nodes will not be updated
        // Since this is only called for visible nodes, skip the check for now
        //
        if (mCreator)
        {
            // Use SceneManager to calculate
            mCreator._populateLightList(this, radius, destList, lightMask);
        }
        else
        {
            destList.clear();
        }
    }
    
    /** Tells the node whether to yaw around it's own local Y axis or a fixed axis of choice.
     @remarks
     This method allows you to change the yaw behaviour of the node - by default, it
     yaws around it's own local Y axis when told to yaw with TransformSpace.TS_LOCAL, this makes it
     yaw around a fixed axis. 
     You only really need this when you're using auto tracking (see setAutoTracking,
     because when you're manually rotating a node you can specify the TransformSpace
     in which you wish to work anyway.
     @param
     useFixed If true, the axis passed in the second parameter will always be the yaw axis no
     matter what the node orientation. If false, the node returns to it's default behaviour.
     @param
     fixedAxis The axis to use if the first parameter is true.
     */
    void setFixedYawAxis( bool useFixed, Vector3 fixedAxis = Vector3.UNIT_Y )
    {
        mYawFixed = useFixed;
        mYawFixedAxis = fixedAxis;
    }
    
    /** Rotate the node around the Y-axis.
     */
    override void yaw(Radian angle, TransformSpace relativeTo = TransformSpace.TS_LOCAL)
    {
        if (mYawFixed)
        {
            rotate(mYawFixedAxis, angle, relativeTo);
        }
        else
        {
            rotate(Vector3.UNIT_Y, angle, relativeTo);
        }
        
    }
    /** Sets the node's direction vector ie it's local -z.
     @remarks
     Note that the 'up' vector for the orientation will automatically be 
     recalculated based on the current 'up' vector (i.e. the roll will 
     remain the same). If you need more control, use setOrientation.
     @param x,y,z The components of the direction vector
     @param relativeTo The space in which this direction vector is expressed
     @param localDirectionVector The vector which normally describes the natural
     direction of the node, usually -Z
     */
    void setDirection(Real x, Real y, Real z, 
                      TransformSpace relativeTo = TransformSpace.TS_LOCAL, 
                     Vector3 localDirectionVector = Vector3.NEGATIVE_UNIT_Z)
    {
        auto v = Vector3(x,y,z);
        setDirection(v, relativeTo, localDirectionVector);
    }
    
    /** Sets the node's direction vector ie it's local -z.
     @remarks
     Note that the 'up' vector for the orientation will automatically be 
     recalculated based on the current 'up' vector (i.e. the roll will 
     remain the same). If you need more control, use setOrientation.
     @param vec The direction vector
     @param relativeTo The space in which this direction vector is expressed
     @param localDirectionVector The vector which normally describes the natural
     direction of the node, usually -Z
     */
    void setDirection(Vector3 vec, TransformSpace relativeTo = TransformSpace.TS_LOCAL, 
                     Vector3 localDirectionVector = Vector3.NEGATIVE_UNIT_Z)
    {
        // Do nothing if given a zero vector
        if (vec == Vector3.ZERO) return;
        
        // The direction we want the local direction point to
        Vector3 targetDir = vec.normalisedCopy();
        
        // Transform target direction to world space
        final switch (relativeTo)
        {
            case TransformSpace.TS_PARENT:
                if (mInheritOrientation)
                {
                    if (mParent)
                    {
                        targetDir = mParent._getDerivedOrientation() * targetDir;
                    }
                }
                break;
            case TransformSpace.TS_LOCAL:
                targetDir = _getDerivedOrientation() * targetDir;
                break;
            case TransformSpace.TS_WORLD:
                // default orientation
                break;
        }
        
        // Calculate target orientation relative to world space
        Quaternion targetOrientation;
        if( mYawFixed )
        {
            // Calculate the quaternion for rotate local Z to target direction
            Vector3 xVec = mYawFixedAxis.crossProduct(targetDir);
            xVec.normalise();
            Vector3 yVec = targetDir.crossProduct(xVec);
            yVec.normalise();
            Quaternion unitZToTarget = Quaternion(xVec, yVec, targetDir);
            
            if (localDirectionVector == Vector3.NEGATIVE_UNIT_Z)
            {
                // Specail case for avoid calculate 180 degree turn
                targetOrientation =
                    Quaternion(-unitZToTarget.y, -unitZToTarget.z, unitZToTarget.w, unitZToTarget.x);
            }
            else
            {
                // Calculate the quaternion for rotate local direction to target direction
                Quaternion localToUnitZ = localDirectionVector.getRotationTo(Vector3.UNIT_Z);
                targetOrientation = unitZToTarget * localToUnitZ;
            }
        }
        else
        {
           Quaternion currentOrient = _getDerivedOrientation();
            
            // Get current local direction relative to world space
            Vector3 currentDir = currentOrient * localDirectionVector;
            
            if ((currentDir+targetDir).squaredLength() < 0.00005f)
            {
                // Oops, a 180 degree turn (infinite possible rotation axes)
                // Default to yaw i.e. use current UP
                targetOrientation =
                    Quaternion(-currentOrient.y, -currentOrient.z, currentOrient.w, currentOrient.x);
            }
            else
            {
                // Derive shortest arc to new direction
                Quaternion rotQuat = currentDir.getRotationTo(targetDir);
                targetOrientation = rotQuat * currentOrient;
            }
        }
        
        // Set target orientation, transformed to parent space
        if (mParent && mInheritOrientation)
            setOrientation(mParent._getDerivedOrientation().UnitInverse() * targetOrientation);
        else
            setOrientation(targetOrientation);
    }
    /** Points the local -Z direction of this node at a point in space.
     @param targetPoint A vector specifying the look at point.
     @param relativeTo The space in which the point resides
     @param localDirectionVector The vector which normally describes the natural
     direction of the node, usually -Z
     */
    void lookAt(Vector3 targetPoint, TransformSpace relativeTo,
               Vector3 localDirectionVector = Vector3.NEGATIVE_UNIT_Z)
    {
        // Calculate ourself origin relative to the given transform space
        Vector3 origin;
        switch (relativeTo)
        {
            default:    // Just in case
            case TransformSpace.TS_WORLD:
                origin = _getDerivedPosition();
                break;
            case TransformSpace.TS_PARENT:
                origin = mPosition;
                break;
            case TransformSpace.TS_LOCAL:
                origin = Vector3.ZERO;
                break;
        }
        
        setDirection(targetPoint - origin, relativeTo, localDirectionVector);
    }
    /** Enables / disables automatic tracking of another SceneNode.
     @remarks
     If you enable auto-tracking, this SceneNode will automatically rotate to
     point it's -Z at the target SceneNode every frame, no matter how 
     it or the other SceneNode move. Note that by default the -Z points at the 
     origin of the target SceneNode, if you want to tweak this, provide a 
     vector in the 'offset' parameter and the target point will be adjusted.
     @param enabled If true, tracking will be enabled and the next 
     parameter cannot be null. If false tracking will be disabled and the 
     current orientation will be maintained.
     @param target Pointer to the SceneNode to track. Make sure you don't
     delete this SceneNode before turning off tracking (e.g. SceneManager::clearScene will
     delete it so be caref ul of this). Can be null if and only if the enabled param is false.
     @param localDirectionVector The local vector considered to be the usual 'direction'
     of the node; normally the local -Z but can be another direction.
     @param offset If supplied, this is the target point in local space of the target node
     instead of the origin of the target node. Good for fine tuning the look at point.
     */
    void setAutoTracking(bool enabled, SceneNode target = null, 
                        Vector3 localDirectionVector = Vector3.NEGATIVE_UNIT_Z,
                        Vector3 offset = Vector3.ZERO)
    {
        if (enabled)
        {
            mAutoTrackTarget = target;
            mAutoTrackOffset = offset;
            mAutoTrackLocalDirection = localDirectionVector;
        }
        else
        {
            mAutoTrackTarget = null;
        }
        if (mCreator)
            mCreator._notifyAutotrackingSceneNode(this, enabled);
    }
    
    /** Get the auto tracking target for this node, if any. */
    ref SceneNode getAutoTrackTarget() { return mAutoTrackTarget; }
    
    /** Get the auto tracking offset for this node, if the node is auto tracking. */
   Vector3 getAutoTrackOffset() { return mAutoTrackOffset; }
    
    /** Get the auto tracking local direction for this node, if it is auto tracking. */
   Vector3 getAutoTrackLocalDirection() { return mAutoTrackLocalDirection; }
    
    /** Internal method used by OGRE to update auto-tracking cameras. */
    void _autoTrack()
    {
        // NB assumes that all scene nodes have been updated
        if (mAutoTrackTarget)
        {
            lookAt(mAutoTrackTarget._getDerivedPosition() + mAutoTrackOffset, 
                   TransformSpace.TS_WORLD, mAutoTrackLocalDirection);
            // update self & children
            _update(true, true);
        }
    }
    
    /** Gets the parent of this SceneNode. */
    SceneNode getParentSceneNode()//
    {
        return cast(SceneNode)(getParent());
    }
    
    /** Makes all objects attached to this node become visible / invisible.
     @remarks    
     This is a shortcut to calling setVisible() on the objects attached
     to this node, and optionally to all objects attached to child
     nodes. 
     @param visible Whether the objects are to be made visible or invisible
     @param cascade If true, this setting cascades into child nodes too.
     */
    void setVisible(bool visible, bool cascade = true)
    {
        foreach (k,v; mObjectsByName)
        {
            v.setVisible(visible);
        }
        
        if (cascade)
        {
            foreach (k,v; mChildren)
            {
                (cast(SceneNode)v).setVisible(visible, cascade);
            }
        }
    }
    /** Inverts the visibility of all objects attached to this node.
     @remarks    
     This is a shortcut to calling setVisible(!isVisible()) on the objects attached
     to this node, and optionally to all objects attached to child
     nodes. 
     @param cascade If true, this setting cascades into child nodes too.
     */
    void flipVisibility(bool cascade = true)
    {
        foreach (k,v; mObjectsByName)
        {
            v.setVisible(!v.getVisible());
        }
        
        if (cascade)
        {
            foreach (k,v; mChildren)
            {
                (cast(SceneNode)v).flipVisibility(cascade);
            }
        }
    }
    
    /** Tells all objects attached to this node whether to display their
     debug information or not.
     @remarks    
     This is a shortcut to calling setDebugDisplayEnabled() on the objects attached
     to this node, and optionally to all objects attached to child
     nodes. 
     @param enabled Whether the objects are to display debug info or not
     @param cascade If true, this setting cascades into child nodes too.
     */
    void setDebugDisplayEnabled(bool enabled, bool cascade = true)
    {
        foreach (k,v; mObjectsByName)
        {
            v.setDebugDisplayEnabled(enabled);
        }
        
        if (cascade)
        {
            foreach (k,v; mChildren)
            {
                (cast(SceneNode)v).setDebugDisplayEnabled(enabled, cascade);
            }
        }
    }
    
    /// As super.getDebugRenderable, except scaling is automatically determined
    DebugRenderable getDebugRenderable()
    {
        Vector3 hs = mWorldAABB.getHalfSize();
        Real sz = std.algorithm.min(hs.x, hs.y);
        sz = std.algorithm.min(sz, hs.z);
        sz = std.algorithm.max(sz, cast(Real)1.0);
        return super.getDebugRenderable(sz);
    }
    
}
/** @} */
/** @} */
