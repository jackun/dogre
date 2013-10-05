module ogre.rendersystem.renderqueue;

//import std.container;

import ogre.compat;
import ogre.scene.movableobject;
import ogre.scene.renderable;
import ogre.rendersystem.renderqueuesortinggrouping;
import ogre.materials.pass;
import ogre.materials.materialmanager;


/** Abstract interface which classes must implement if they wish to receive
        events from the render queue. 
    @remarks
        The OGRE render queue is divided into several queue groups, as defined by
        ubyte. A class may implement this interface, and register itself
        as a listener by calling SceneManager::addRenderQueueListener. After doing so,
        the class will receive an event before and after each queue group is sent to 
        the rendering system.
    @par
        The event listeners have an option to make a queue either be skipped, or to repeat.
        Note that if multiple listeners are registered, the one registered last has the final
        say, although options set by previous listeners will not be changed if the latest
        does not express a preference.
    */
interface RenderQueueListener
{
    /** Event raised before all render queues are processed. 
        */
    void preRenderQueues();
    /** Event raised after all render queues are processed. 
        */
    void postRenderQueues();
    
    /** Event raised before a queue group is rendered. 
        @remarks
            This method is called by the SceneManager before each queue group is
            rendered. 
        @param queueGroupId The id of the queue group which is about to be rendered
        @param invocation Name of the invocation which is causing this to be 
            called (@see RenderQueueInvocation)
        @param skipThisInvocation A boolean passed by reference which is by default set to 
            false. If the event sets this to true, the queue will be skipped and not
            rendered. Note that in this case the renderQueueEnded event will not be raised
            for this queue group.
        */
    void renderQueueStarted(ubyte queueGroupId,string invocation, 
                            ref bool skipThisInvocation);
    
    /** Event raised after a queue group is rendered. 
        @remarks
            This method is called by the SceneManager after each queue group is
            rendered. 
        @param queueGroupId The id of the queue group which has just been rendered
        @param invocation Name of the invocation which is causing this to be 
            called (@see RenderQueueInvocation)
        @param repeatThisInvocation A boolean passed by reference which is by default set to 
            false. If the event sets this to true, the queue which has just been
            rendered will be repeated, and the renderQueueStarted and renderQueueEnded
            events will also be fired for it again.
        */
    void renderQueueEnded(ubyte queueGroupId,string invocation, 
                          ref bool repeatThisInvocation);
}


/** Enumeration of queue groups, by which the application may group queued renderables
    so that they are rendered together with events in between
@remarks
    When passed into methods these are actually passed as a ubyte to allow you
    to use values in between if you want to.
*/
enum RenderQueueGroupID : byte
{
    /// Use this queue for objects which must be rendered first e.g. backgrounds
    RENDER_QUEUE_BACKGROUND = 0,
    /// First queue (after backgrounds), used for skyboxes if rendered first
    RENDER_QUEUE_SKIES_EARLY = 5,
    RENDER_QUEUE_1 = 10,
    RENDER_QUEUE_2 = 20,
    RENDER_QUEUE_WORLD_GEOMETRY_1 = 25,
    RENDER_QUEUE_3 = 30,
    RENDER_QUEUE_4 = 40,
    /// The default render queue
    RENDER_QUEUE_MAIN = 50,
    RENDER_QUEUE_6 = 60,
    RENDER_QUEUE_7 = 70,
    RENDER_QUEUE_WORLD_GEOMETRY_2 = 75,
    RENDER_QUEUE_8 = 80,
    RENDER_QUEUE_9 = 90,
    /// Penultimate queue(before overlays), used for skyboxes if rendered last
    RENDER_QUEUE_SKIES_LATE = 95,
    /// Use this queue for objects which must be rendered last e.g. overlays
    RENDER_QUEUE_OVERLAY = 100,
    /// Final possible render queue, don't exceed this
    RENDER_QUEUE_MAX = 105
}

enum uint OGRE_RENDERABLE_DEFAULT_PRIORITY = 100;

/** Class to manage the scene object rendering queue.
    @remarks
        Objects are grouped by material to minimise rendering state changes. The map from
        material to renderable object is wrapped in a class for ease of use.
    @par
        This class now includes the concept of 'queue groups' which allows the application
        adding the renderable to specifically schedule it so that it is included in
        a discrete group. Good for separating renderables into the main scene,
        backgrounds and overlays, and also could be used in the future for more
        complex multipass routines like stenciling.
*/
class RenderQueue //: public RenderQueueAlloc
{
public:
    
    /** Class to listen in on items being added to the render queue.
    @remarks
        Use RenderQueue::setRenderableListener to get callbacks when an item
        is added to the render queue.
    */
    interface RenderableListener
    {
        /** Method called when a Renderable is added to the queue.
        @remarks
            You can use this event hook to alter the Technique used to
            render a Renderable as the item is added to the queue. This is
            a low-level way to override the material settings for a given
            Renderable on the fly.
        @param rend The Renderable being added to the queue
        @param groupID The render queue group this Renderable is being added to
        @param priority The priority the Renderable has been given
        @param ppTech A pointer to the pointer to the Technique that is
            intended to be used; you can alter this to an alternate Technique
            if you so wish (the Technique doesn't have to be from the same
            Material either).
        @param pQueue Pointer to the render queue that this object is being
            added to. You can for example call this back to duplicate the
            object with a different technique
        @return true to allow the Renderable to be added to the queue,
            false if you want to prevent it being added
        */
        bool renderableQueued(Renderable rend, ubyte groupID,
                              ushort priority, Technique ppTech, RenderQueue pQueue);
    }
    
protected:
    alias RenderQueueGroup[ubyte] RenderQueueGroupMap;
    RenderQueueGroupMap mGroups;
    /// The current default queue group
    ubyte mDefaultQueueGroup;
    /// The default priority
    ushort mDefaultRenderablePriority;
    
    bool mSplitPassesByLightingType;
    bool mSplitNoShadowPasses;
    bool mShadowCastersCannotBeReceivers;
    
    RenderableListener mRenderableListener;
public:
    this()
    {
        
        mSplitPassesByLightingType = false;
        mSplitNoShadowPasses = false;
        mShadowCastersCannotBeReceivers = false;
        mRenderableListener = null;
        // Create the 'main' queue up-front since we'll always need that
        mGroups[RenderQueueGroupID.RENDER_QUEUE_MAIN] =
            new RenderQueueGroup(this,
                                 mSplitPassesByLightingType,
                                 mSplitNoShadowPasses,
                                 mShadowCastersCannotBeReceivers);
        
        // set default queue
        mDefaultQueueGroup = RenderQueueGroupID.RENDER_QUEUE_MAIN;
        mDefaultRenderablePriority = OGRE_RENDERABLE_DEFAULT_PRIORITY;
        
    }
    
    ~this()
    {
        // trigger the pending pass updates, otherwise we could leak
        Pass.processPendingPassUpdates();
        
        // Destroy the queues for good
        foreach (k,v; mGroups)
        {
            destroy(v);
        }
        mGroups.clear();
    }
    
    ref RenderQueueGroupMap _getQueueGroups()
    {
        return mGroups;
    }
    
    /** Empty the queue - should only be called by SceneManagers.
    @param destroyPassMaps Set to true to destroy all pass maps so that
        the queue is completely clean (useful when switching scene managers)
    */
    void clear(bool destroyPassMaps = false)
    {
        // Clear the queues
        auto scnIt = SceneManagerEnumerator.getSingleton().getSceneManagers();
        
        // Note: We clear dirty passes from all RenderQueues in all
        // SceneManagers, because the following recalculation of pass hashes
        // also considers all RenderQueues and could become inconsistent, otherwise.
        foreach(sceneMgr; scnIt)
        {
            RenderQueue queue = sceneMgr.getRenderQueue();
            
            foreach (k,v; queue.mGroups)
            {
                v.clear(destroyPassMaps);
            }
        }
        
        // Now trigger the pending pass updates
        Pass.processPendingPassUpdates();
        
        // NB this leaves the items present (but empty)
        // We're assuming that frame-by-frame, the same groups are likely to
        //  be used, so no point destroying the vectors and incurring the overhead
        //  that would cause, let them be destroyed in the destructor.
    }
    
    /** Get a render queue group.
    @remarks
        OGRE registers new queue groups as they are requested,
        therefore this method will always return a valid group.
    */
    RenderQueueGroup getQueueGroup(ubyte groupID)
    {
        // Find group
        RenderQueueGroup pGroup;
        
        auto groupIt = groupID in mGroups;
        if (groupIt is null)
        {
            debug(STDERR) std.stdio.stderr.writeln("RenderQueue.getQueueGroup creating new group ", groupID);
            // Insert new
            pGroup = new RenderQueueGroup(this,
                                          mSplitPassesByLightingType,
                                          mSplitNoShadowPasses,
                                          mShadowCastersCannotBeReceivers);
            mGroups[groupID] = pGroup;
        }
        else
        {
            pGroup = *groupIt;
        }
        debug(STDERR) std.stdio.stderr.writeln("RenderQueue.getQueueGroup getting group ", groupID);
        return pGroup;
        
    }
    
    /** Add a renderable object to the queue.
    @remarks
        This methods adds a Renderable to the queue, which will be rendered later by
        the SceneManager. This is the advanced version of the call which allows the renderable
        to be added to any queue.
    @note
        Called by implementation of MovableObject::_updateRenderQueue.
    @param
        pRend Pointer to the Renderable to be added to the queue
    @param
        groupID The group the renderable is to be added to. This
        can be used to schedule renderable objects in separate groups such that the SceneManager
        respects the divisions between the groupings and does not reorder them outside these
        boundaries. This can be handy for overlays where no matter what you want the overlay to
        be rendered last.
    @param
        priority Controls the priority of the renderable within the queue group. If this number
        is raised, the renderable will be rendered later in the group compared to it's peers.
        Don't use this unless you really need to, manually ordering renderables prevents OGRE
        from sorting them for best efficiency. However this could be useful for ordering 2D
        elements manually for example.
    */
    void addRenderable(Renderable pRend, ubyte groupID, ushort priority)
    {
        // Find group
        RenderQueueGroup pGroup = getQueueGroup(groupID);
        debug(STDERR) std.stdio.stderr.writeln("RenderQueue.addRenderable ", groupID, ", ", pRend);
        
        Technique pTech;
        
        // tell material it's been used
        if (!pRend.getMaterial().isNull())// !is null)
            pRend.getMaterial().getAs().touch();
        
        // Check material & technique supplied (the former since the default implementation
        // of getTechnique is based on it for backwards compatibility
        if(pRend.getMaterial().isNull() || !pRend.getTechnique())
        {
            // Use default base white
            SharedPtr!Material baseWhite = MaterialManager.getSingleton().getByName("BaseWhite");
            pTech = baseWhite.getAs().getTechnique(0);
        }
        else
            pTech = pRend.getTechnique();
        
        if (mRenderableListener)
        {
            // Allow listener to override technique and to abort
            if (!mRenderableListener.renderableQueued(pRend, groupID, priority,
                                                      pTech, this))
                return; // rejected
            
            // tell material it's been used (incase changed)
            pTech.getParent().touch();
        }
        
        pGroup.addRenderable(pRend, pTech, priority);
        
    }
    
    /** Add a renderable object to the queue.
    @remarks
        This methods adds a Renderable to the queue, which will be rendered later by
        the SceneManager. This is the simplified version of the call which does not
        require a priority to be specified. The queue priority is take from the
        current default (see setDefaultRenderablePriority).
    @note
        Called by implementation of MovableObject::_updateRenderQueue.
    @param pRend
        Pointer to the Renderable to be added to the queue
    @param groupId
        The group the renderable is to be added to. This
        can be used to schedule renderable objects in separate groups such that the SceneManager
        respects the divisions between the groupings and does not reorder them outside these
        boundaries. This can be handy for overlays where no matter what you want the overlay to
        be rendered last.
    */
    void addRenderable(Renderable pRend, ubyte groupId)
    {
        addRenderable(pRend, groupId, mDefaultRenderablePriority);
    }
    
    /** Add a renderable object to the queue.
    @remarks
        This methods adds a Renderable to the queue, which will be rendered later by
        the SceneManager. This is the simplified version of the call which does not
        require a queue or priority to be specified. The queue group is taken from the
        current default (see setDefaultQueueGroup).  The queue priority is take from the
        current default (see setDefaultRenderablePriority).
    @note
        Called by implementation of MovableObject::_updateRenderQueue.
    @param
        pRend Pointer to the Renderable to be added to the queue
    */
    void addRenderable(Renderable pRend)
    {
        addRenderable(pRend, mDefaultQueueGroup, mDefaultRenderablePriority);
    }
    
    /** Sets the current default queue group, which will be used for all renderable which do not
        specify which group they wish to be on. See the enum RenderQueueGroupID for what kind of
        values can be used here.
    */
    void setDefaultQueueGroup(ubyte grp)
    {
        mDefaultQueueGroup = grp;
    }
    
    /** Gets the current default queue group, which will be used for all renderable which do not
        specify which group they wish to be on.
    */
    ubyte getDefaultQueueGroup()
    {
        return mDefaultQueueGroup;
    }
    
    /** Sets the current default renderable priority,
        which will be used for all renderables which do not
        specify which priority they wish to use.
    */
    void setDefaultRenderablePriority(ushort priority)
    {
        mDefaultRenderablePriority = priority;
    }
    
    /** Gets the current default renderable priority, which will be used for all renderables which do not
        specify which priority they wish to use.
    */
    ushort getDefaultRenderablePriority()
    {
        return mDefaultRenderablePriority;
    }
    
    
    /** Internal method, returns an iterator for the queue groups. */
    //QueueGroupIterator _getQueueGroupIterator();
    //ConstQueueGroupIterator _getQueueGroupIterator();
    
    /** Sets whether or not the queue will split passes by their lighting type,
        ie ambient, per-light and decal.
    */
    void setSplitPassesByLightingType(bool split)
    {
        mSplitPassesByLightingType = split;
        
        foreach (k,v; mGroups)
        {
            v.setSplitPassesByLightingType(split);
        }
    }
    
    /** Gets whether or not the queue will split passes by their lighting type,
        ie ambient, per-light and decal.
    */
    bool getSplitPassesByLightingType()
    {
        return mSplitPassesByLightingType;
    }
    
    /** Sets whether or not the queue will split passes which have shadow receive
    turned off (in their parent material), which is needed when certain shadow
    techniques are used.
    */
    void setSplitNoShadowPasses(bool split)
    {
        mSplitNoShadowPasses = split;
        
        foreach (k,v; mGroups)
        {
            v.setSplitNoShadowPasses(split);
        }
    }
    
    /** Gets whether or not the queue will split passes which have shadow receive
    turned off (in their parent material), which is needed when certain shadow
    techniques are used.
    */
    bool getSplitNoShadowPasses()
    {
        return mSplitNoShadowPasses;
    }
    
    /** Sets whether or not objects which cast shadows should be treated as
        never receiving shadows.
    */
    void setShadowCastersCannotBeReceivers(bool b)
    {
        mShadowCastersCannotBeReceivers = b;
    }
    
    /** Gets whether or not objects which cast shadows should be treated as
    never receiving shadows.
    */
    bool getShadowCastersCannotBeReceivers()
    {
        return mShadowCastersCannotBeReceivers;
    }
    
    /** Set a renderable listener on the queue.
    @remarks
        There can only be a single renderable listener on the queue, since
        that listener has complete control over the techniques in use.
    */
    void setRenderableListener(RenderableListener listener)
    { mRenderableListener = listener; }
    
    RenderableListener getRenderableListener()
    { return mRenderableListener; }
    
    /** Merge render queue.
    */
    void merge( RenderQueue rhs )
    {
        auto it = rhs._getQueueGroups( );
        
        foreach(groupID, pSrcGroup; it)
        {
            RenderQueueGroup pDstGroup = getQueueGroup( groupID );
            
            pDstGroup.merge( pSrcGroup );
        }
    }
    /** Utility method to perform the standard actions associated with
        getting a visible object to add itself to the queue. This is
        a replacement for SceneManager implementations of the associated
        tasks related to calling MovableObject::_updateRenderQueue.
    */
    void processVisibleObject(MovableObject mo,
                              Camera cam,
                              bool onlyShadowCasters,
                              VisibleObjectsBoundsInfo visibleBounds)
    {
        debug(STDERR) std.stdio.stderr.writeln("RQ.processVisibleObject: ", mo,", ", mo.isVisible());
        
        mo._notifyCurrentCamera(cam);
        if (mo.isVisible())
        {
            bool receiveShadows = getQueueGroup(mo.getRenderQueueGroup()).getShadowsEnabled()
                && mo.getReceivesShadows();
            
            if (!onlyShadowCasters || mo.getCastShadows())
            {
                mo._updateRenderQueue(this);
                //if (visibleBounds)
                {
                    visibleBounds.merge(mo.getWorldBoundingBox(true),
                                        mo.getWorldBoundingSphere(true), cam,
                                        receiveShadows);
                }
            }
            // not shadow caster, receiver only?
            else if (onlyShadowCasters && !mo.getCastShadows() &&
                     receiveShadows)
            {
                visibleBounds.mergeNonRenderedButInFrustum(mo.getWorldBoundingBox(true),
                                                           mo.getWorldBoundingSphere(true), cam);
            }
        }
        
    }
    
}

/** Class representing the invocation of queue groups in a RenderQueue.
    @remarks
        The default behaviour for OGRE's render queue is to render each queue
        group in turn, dealing with shadows automatically, and rendering solids
        in grouped passes, followed by transparent objects in descending order.
        This class, together with RenderQueueInvocationSequence and the ability
        to associate one with a Viewport, allows you to change that behaviour
        and render queue groups in arbitrary sequence, repeatedly, and to skip
        shadows, change the ordering of solids, or even prevent OGRE controlling
        the render state during a particular invocation for special effects.
    @par
        Note that whilst you can change the ordering of rendering solids, you 
        can't change the ordering on transparent objects, since to do this would
        cause them to render incorrectly.
    @par
        As well as using this class directly and using the options it provides you
        with, you can also provide subclasses of it to a 
        RenderQueueInvocationSequence instance if you want to gain ultimate control.
    @note
        Invocations will be skipped if there are scene-level options preventing
        them being rendered - for example special-case render queues and
        render queue listeners that dictate this.
    */
class RenderQueueInvocation
{
protected:
    /// Target queue group
    ubyte mRenderQueueGroupID;
    /// Invocation identifier - used in listeners
    string mInvocationName;
    /// Solids ordering mode
    QueuedRenderableCollection.OrganisationMode mSolidsOrganisation;
    /// Suppress shadows processing in this invocation?
    bool mSuppressShadows;
    /// Suppress OGRE's render state management?
    bool mSuppressRenderStateChanges;
public:
    /** Constructor
        @param renderQueueGroupID ID of the queue this will target
        @param invocationName Optional name to uniquely identify this
            invocation from others in a RenderQueueListener
        */
    this(ubyte renderQueueGroupID, 
        string invocationName = null)
    {
        mRenderQueueGroupID = renderQueueGroupID;
        mInvocationName = invocationName;
        mSolidsOrganisation = QueuedRenderableCollection.OrganisationMode.OM_PASS_GROUP;
        mSuppressShadows = false;
        mSuppressRenderStateChanges = false;
    }
    
    ~this() {}
    
    /// Get the render queue group id
    ubyte getRenderQueueGroupID(){ return mRenderQueueGroupID; }
    
    /// Get the invocation name (may be blank if not set by creator)
   string getInvocationName(){ return mInvocationName; }
    
    /** Set the organisation mode being used for solids in this queue group
        invocation.
        */
    void setSolidsOrganisation(QueuedRenderableCollection.OrganisationMode org)  
    { mSolidsOrganisation = org; }
    
    /** Get the organisation mode being used for solids in this queue group
            invocation.
        */
    QueuedRenderableCollection.OrganisationMode
    getSolidsOrganisation(){ return mSolidsOrganisation; }
    
    /** Sets whether shadows are suppressed when invoking this queue. 
        @remarks
            When doing effects you often will want to suppress shadow processing
            if shadows will already have been done by a previous render.
        */
    void setSuppressShadows(bool suppress) 
    { mSuppressShadows =  suppress; }
    
    /** Gets whether shadows are suppressed when invoking this queue. 
        */
    bool getSuppressShadows(){ return mSuppressShadows; }
    
    /** Sets whether render state changes are suppressed when invoking this queue. 
        @remarks
            When doing special effects you may want to set up render state yourself
            and have it apply for the entire rendering of a queue. In that case, 
            you should call this method with a parameter of 'true', and use a
            RenderQueueListener to set the render state directly on RenderSystem
            yourself before the invocation.
        @par
            Suppressing render state changes is only intended for advanced use, 
            don't use it if you're unsure of the effect. The only RenderSystem
            calls made are to set the world matrix for each object (note - 
            view an projection matrices are NOT SET - they are under your control) 
            and to render the object; it is up to the caller to do everything else, 
            including enabling any vertex / fragment programs and updating their 
            parameter state, and binding parameters to the RenderSystem.
            We advise you use a RenderQueueListener in order to get a notification
            when this invocation is going to happen (use an invocation name to
            identify it if you like), at which point you can set the state you
            need to apply before the objects are rendered.
        */
    void setSuppressRenderStateChanges(bool suppress) 
    { mSuppressRenderStateChanges =  suppress; }
    
    /** Gets whether shadows are suppressed when invoking this queue. 
        */
    bool getSuppressRenderStateChanges(){ return mSuppressRenderStateChanges; }
    
    /** Invoke this class on a concrete queue group.
        @remarks
            Implementation will send the queue group to the target scene manager
            after doing what it needs to do.
        */
    void invoke(RenderQueueGroup group, SceneManager targetSceneManager)
    {
        bool oldShadows = targetSceneManager._areShadowsSuppressed();
        bool oldRSChanges = targetSceneManager._areRenderStateChangesSuppressed();
        
        targetSceneManager._suppressShadows(mSuppressShadows);
        targetSceneManager._suppressRenderStateChanges(mSuppressRenderStateChanges);
        
        targetSceneManager._renderQueueGroupObjects(group, mSolidsOrganisation);
        
        targetSceneManager._suppressShadows(oldShadows);
        targetSceneManager._suppressRenderStateChanges(oldRSChanges);
        
    }
    
    /// Invocation identifier for shadows
    static string RENDER_QUEUE_INVOCATION_SHADOWS = "SHADOWS";
}


/// List of RenderQueueInvocations
//typedef vector<RenderQueueInvocation*>::type RenderQueueInvocationList;
//typedef VectorIterator<RenderQueueInvocationList> RenderQueueInvocationIterator;
alias RenderQueueInvocation[] RenderQueueInvocationList;


/** Class to hold a linear sequence of RenderQueueInvocation objects. 
    @remarks
        This is just a simple data holder class which contains a list of 
        RenderQueueInvocation objects representing the sequence of invocations
        made for a viewport. It's only real purpose is to ensure that 
        RenderQueueInvocation instances are deleted on shutdown, since you can
        provide your own subclass instances on RenderQueueInvocation. Remember
        that any invocation instances you give to this class will be deleted
        by it when it is cleared / destroyed.
    */
class RenderQueueInvocationSequence
{
protected:
    string mName;
    RenderQueueInvocationList mInvocations;
public:
    this(string name)
    {
        mName = name;
    }
    ~this()
    {
        clear();
    }
    
    /** Get the name of this sequence. */
   string getName(){ return mName; }
    
    /** Add a standard invocation to the sequence.
        @param renderQueueGroupID The ID of the render queue group
        @param invocationName Optional name to identify the invocation, useful
            for listeners if a single queue group is invoked more than once
        @return A new RenderQueueInvocatin instance which you may customise
        */
    RenderQueueInvocation add(ubyte renderQueueGroupID, 
                                 string invocationName)
    {
        RenderQueueInvocation ret = 
            new RenderQueueInvocation(renderQueueGroupID, invocationName);
        
        mInvocations.insert(ret);
        
        return ret;
        
    }
    
    /** Add a custom invocation to the sequence.
        @remarks
            Use this to add your own custom subclasses of RenderQueueInvocation
            to the sequence; just remember that this class takes ownership of
            deleting this pointer when it is cleared / destroyed.
        */
    void add(RenderQueueInvocation i)
    {
        mInvocations.insert(i);
    }
    
    /** Get the number of invocations in this sequence. */
    size_t size(){ return mInvocations.length; }
    
    /** .length seems to be more D-ish */
    @property 
    size_t length() { return mInvocations.length; }
    
    /** Clear and delete all invocations in this sequence. */
    void clear()
    {
        foreach (i; mInvocations)
        {
            destroy(i);
        }
        mInvocations.clear();
    }
    
    /** Gets the details of an invocation at a given index. */
    RenderQueueInvocation get(size_t index)
    {
        if (index >= size())
            throw new ItemNotFoundError(
                "Index out of bounds", 
                "RenderQueueInvocationSequence.get");
        
        return mInvocations[index];
    }
    
    /** Removes (and deletes) an invocation by index. */
    void remove(size_t index)
    {
        if (index >= size())
            throw new ItemNotFoundError(
                "Index out of bounds", 
                "RenderQueueInvocationSequence.remove");
        
        auto i = mInvocations[index];
        destroy(i);
        mInvocations.removeFromArray(i);
        
    }
    
    /** Get an iterator over the invocations. */
    /*RenderQueueInvocationIterator iterator()
    {
        return RenderQueueInvocationIterator(mInvocations.begin(), mInvocations.end());
    }*/
    
    /** Get an the invocations list. */
    RenderQueueInvocationList getList()
    {
        return mInvocations;
    }  
}
