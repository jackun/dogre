module ogre.rendersystem.renderqueuesortinggrouping;

private
{
    import std.algorithm;
    import std.array;
    //import std.container;
}

import ogre.compat;
import ogre.general.radixsort;
import ogre.scene.renderable;
import ogre.math.maths;
import ogre.materials.pass;
import ogre.rendersystem.renderqueue;

/** \addtogroup Core
    *  @{
    */
/** \addtogroup RenderSystem
    *  @{
    */
/** Struct associating a single Pass with a single Renderable. 
        This is used to for objects sorted by depth and thus not
        grouped by pass.
    */
//struct 
class RenderablePass
{
    /// Pointer to the Renderable details
    Renderable renderable;
    /// Pointer to the Pass
    Pass pass;
    
    this(Renderable rend, Pass p) 
    {
        renderable = rend;
        pass = p;
    }
}


/** Visitor interface for items in a QueuedRenderableCollection.
    @remarks
        Those wishing to iterate over the items in a 
        QueuedRenderableCollection should implement this visitor pattern,
        since internal organisation of the collection depends on the 
        sorting method in use.
    */
interface QueuedRenderableVisitor
{
    /** Called when visiting a RenderablePass, i.e. items in a
            sorted collection where items are not grouped by pass.
        @remarks
            If this is called, neither of the other 2 visit methods
            will be called.
        */
    void visit(RenderablePass rp);
    
    /* When visiting a collection grouped by pass, this is
            called when the grouping pass changes.
        @remarks
            If this method is called, the RenderablePass visit 
            method will not be called for this collection. The 
            Renderable visit method will be called for each item
            underneath the pass grouping level.
        @return True to continue, false to skip the Renderables underneath
        */
    bool visit(Pass p);
    /** Visit method called once per Renderable on a grouped 
            collection.
        @remarks
            If this method is called, the RenderablePass visit 
            method will not be called for this collection. 
        */
    void visit(Renderable r);
}

/** Lowest level collection of renderables.
    @remarks
        To iterate over items in this collection, you must call
        the accept method and supply a QueuedRenderableVisitor.
        The order of the iteration, and whether that iteration is
        over a RenderablePass list or a 2-level grouped list which 
        causes a visit call at the Pass level, and a call for each
        Renderable underneath.
    */
class QueuedRenderableCollection //: public RenderQueueAlloc
{
public:
    /** Organisation modes required for this collection.
        @remarks
            This affects the internal placement of the items added to this collection;
            if only one type of sorting / grouping is to be required, then renderables
            can be stored only once, whilst if multiple types are going to be needed
            then internally there will be multiple organisations. Changing the organisation
            needs to be done when the collection is empty.
        */      
    enum OrganisationMode
    {
        /// Group by pass
        OM_PASS_GROUP = 1,
        /// Sort descending camera distance
        OM_SORT_DESCENDING = 2,
        /** Sort ascending camera distance 
                Note value overlaps with descending since both use same sort
            */
        OM_SORT_ASCENDING = 6
    }
    
protected:

    static this()
    {
        msRadixSorter1 = new RadixSort!(RenderablePassList, RenderablePass, uint);
        msRadixSorter2 = new RadixSort!(RenderablePassList, RenderablePass, float);
    }
    
    /// Comparator to order pass groups
    static bool PassGroupLess(Pass a, Pass b)//
    {
        // Sort by passHash, which is pass, then texture unit changes
        uint hasha = a.getHash();
        uint hashb = b.getHash();
        if (hasha == hashb)
        {
            // Must differentTransparentQueueItemLessiate by pointer incase 2 passes end up with the same hash
            return a < b;
        }
        else
        {
            return hasha < hashb;
        }
    }
    
    /// Comparator to order objects by descending camera distance
    struct DepthSortDescendingLess
    {
        Camera camera;
        
        this(Camera cam)
        {
            camera = cam;
        }
        
        bool opCall(RenderablePass a, RenderablePass b)
        {
            if (a.renderable == b.renderable)
            {
                // Same renderable, sort by pass hash
                return a.pass.getHash() < b.pass.getHash();
            }
            else
            {
                // Different renderables, sort by depth
                Real adepth = a.renderable.getSquaredViewDepth(camera);
                Real bdepth = b.renderable.getSquaredViewDepth(camera);
                if (Math.RealEqual(adepth, bdepth))
                {
                    // Must return deterministic result, doesn't matter what
                    return a.pass < b.pass;
                }
                else
                {
                    // Sort DESCENDING by depth (i.e. far objects first)
                    return (adepth > bdepth);
                }
            }
            
        }
    }
    
    /** Vector of RenderablePass objects, this is built on the assumption that
         vectors only ever increase in size, so even if we do clear() the memory stays
         allocated, ie fast */
    //typedef vector<RenderablePass>::type RenderablePassList;
    //typedef vector<Renderable*>::type RenderableList;
    alias RenderablePass[] RenderablePassList;
    alias Renderable[]     RenderableList;
    /** Map of pass to renderable lists, this is a grouping by pass. */
    //typedef map<Pass*, RenderableList*, PassGroupLess>::type PassGroupRenderableMap;
    //alias MultiMap!(Pass, RenderableList, PassGroupLess) PassGroupRenderableMap;
    alias RenderableList[Pass] PassGroupRenderableMap;
    
    /// Functor for accessing sort value 1 for radix sort (Pass)
    struct RadixSortFunctorPass
    {
        uint opCall(RenderablePass p)
        {
            return p.pass.getHash();
        }
    }
    
    
    /// Radix sorter for accessing sort value 1 (Pass)
    static RadixSort!(RenderablePassList, RenderablePass, uint) msRadixSorter1;
    
    /// Functor for descending sort value 2 for radix sort (distance)
    struct RadixSortFunctorDistance
    {
        Camera camera;
        
        this(Camera cam)
        {
            camera = cam;
        }
        
        float opCall(RenderablePass p)
        {
            // Sort DESCENDING by depth (ie far objects first), use negative distance
            // here because radix sorter always dealing with accessing sort
            return cast(float)(- p.renderable.getSquaredViewDepth(camera));
        }
    }
    
    /*float RadixSortFunctorDistance(RenderablePass p, Camera camera)
    {
        // Sort DESCENDING by depth (ie far objects first), use negative distance
        // here because radix sorter always dealing with accessing sort
        return cast(float)(- p.renderable.getSquaredViewDepth(camera));
    }*/
    
    /// Radix sorter for sort value 2 (distance)
    static RadixSort!(RenderablePassList, RenderablePass, float) msRadixSorter2;
    
    /// Bitmask of the organisation modes requested
    ubyte mOrganisationMode;
    
    /// Grouped 
    public  PassGroupRenderableMap mGrouped;
    /// Sorted descending (can iterate backwards to get ascending)
    public RenderablePassList mSortedDescending;
    
    /// Internal visitor implementation
    void acceptVisitorGrouped(QueuedRenderableVisitor visitor)
    {
        debug(STDERR) std.stdio.stderr.writeln("QRC.acceptVisitorGrouped: ",mGrouped);
        foreach (k,rendList; mGrouped)
        {
            debug(STDERR) std.stdio.stderr.writeln("\t ", k,"=",rendList);
            // Fast bypass if this group is now empty
            if (rendList.empty()) continue;
            
            // Visit Pass - allow skip
            if (!visitor.visit(k))
                continue;
            
            foreach (i; rendList)
            {
                // Visit Renderable
                visitor.visit(cast(Renderable)i);
            }
        } 
        
    }
    
    /// Internal visitor implementation
    void acceptVisitorDescending(QueuedRenderableVisitor visitor)
    {
        debug(STDERR) std.stdio.stderr.writeln("QRC.acceptVisitorDescending: ",mSortedDescending);
        // List is already in descending order, so iterate forward
        
        foreach (i; mSortedDescending)
        {
            visitor.visit(cast(RenderablePass)i);
        }
    }
    
    /// Internal visitor implementation
    void acceptVisitorAscending(QueuedRenderableVisitor visitor)
    {
        debug(STDERR) std.stdio.stderr.writeln("QRC.acceptVisitorAscending: ",mSortedDescending);
        // List is in descending order, so iterate in reverse
        foreach_reverse (i; mSortedDescending)
        {
            visitor.visit(cast(RenderablePass)i);
        }
    }
    
public:
    this() { mOrganisationMode = 0; }
    ~this()
    {
        // destroy all the pass map entries (rather than clearing)
        foreach (k,v; mGrouped)
        {
            // Free the list associated with this pass
            destroy(v);
        }
        
    }
    
    /// Empty the collection
    void clear()
    {
        foreach (k,v; mGrouped)
        {
            // Clear the list associated with this pass, but leave the pass entry
            v.clear();
        }
        
        // Clear sorted list
        mSortedDescending.clear();
    }
    
    /** Remove the group entry (if any) for a given Pass.
        @remarks
            To be used when a pass is destroyed, such that any
            grouping level for it becomes useless.
        */  
    void removePassGroup(Pass p)
    {
        auto i = p in mGrouped;
        if (i !is null)
        {
            // erase from map
            mGrouped.remove(p);
            // free memory
            destroy(*i);
        }
    }
    
    /** Reset the organisation modes required for this collection. 
        @remarks
            You can only do this when the collection is empty.
        @see OrganisationMode
        */
    void resetOrganisationModes()
    {
        mOrganisationMode = 0; 
    }
    
    /** Add a required sorting / grouping mode to this collection when next used.
        @remarks
            You can only do this when the collection is empty.
        @see OrganisationMode
        */
    void addOrganisationMode(OrganisationMode om) 
    { 
        mOrganisationMode |= om; 
    }
    
    /// Add a renderable to the collection using a given pass
    void addRenderable(Pass pass, Renderable rend)
    {
        debug(STDERR) std.stdio.stderr.writeln("QRC.addRenderable: ",pass, ", ", rend);
        // ascending and descending sort both set bit 1
        if (mOrganisationMode & OrganisationMode.OM_SORT_DESCENDING)
        {
            mSortedDescending.insert(new RenderablePass(rend, pass));
        }
        
        if (mOrganisationMode & OrganisationMode.OM_PASS_GROUP)
        {
            auto i = pass in mGrouped;
            if (i is null)
            {
                //pair!(PassGroupRenderableMap, bool) retPair;
                // Create new pass entry, build a new list
                // Note that this pass and list are never destroyed until the 
                // engine shuts down, or a pass is destroyed or has it's hash
                // recalculated, although the lists will be cleared

                //TODO assert if pass already in PassGroupRenderableMap?
                mGrouped[pass] = null;
                //       "Error inserting new pass entry into PassGroupRenderableMap");
                i = &mGrouped[pass];
            }
            
            //TODO D : check if included already?
            if(!(*i).inArray(rend))
                // Insert renderable
                (*i).insert(rend);
            
        }
        
    }
    
    //Workaround
    static void sort_(Camera cam, ref RenderablePassList list)
    {
        auto s = DepthSortDescendingLess(cam);
        .sort!(s, SwapStrategy.stable)(list);
    }
    
    /** Perform any sorting that is required on this collection.
        @param cam The camera
        */
    void sort(Camera cam)
    {
        // ascending and descending sort both set bit 1
        // We always sort descending, because the only difference is in the
        // acceptVisitor method, where we iterate in reverse in ascending mode
        if (mOrganisationMode & OrganisationMode.OM_SORT_DESCENDING)
        {
            
            // We can either use a stable_sort and the 'less' implementation,
            // or a 2-pass radix sort (once by pass, then by distance, since
            // radix sorting is inherently stable this will work)
            // We use stable_sort if the number of items is 512 or less, since
            // the complexity of the radix sort is approximately O(10N), since 
            // each sort is O(5N) (1 pass histograms, 4 passes sort)
            // Since stable_sort has a worst-case performance of O(N(logN)^2)
            // the performance tipping point is from about 1500 items, but in
            // stable_sorts best-case scenario O(NlogN) it would be much higher.
            // Take a stab at 2000 items.
            
            if (mSortedDescending.length > 2000)
            {
                // sort by pass
                RadixSortFunctorPass byPass;
                msRadixSorter1.sort(mSortedDescending, byPass);
                // sort by depth
                auto byDist = RadixSortFunctorDistance(cam);
                msRadixSorter2.sort(mSortedDescending, byDist);
            }
            else
            {
                //std::stable_sort(
                //    mSortedDescending.begin(), mSortedDescending.end(), 
                //    DepthSortDescendingLess(cam));
                //FIXME http://d.puremagic.com/issues/show_bug.cgi?id=4481#c12
                //dmd: glue.c:786: virtual void FuncDeclaration::toObjFile(int): Assertion `!vthis->csym' failed.
                //auto s = DepthSortDescendingLess(cam);
                //.sort!(s, SwapStrategy.stable)(mSortedDescending);
                sort_(cam, mSortedDescending);
            }
        }
        
        // Nothing needs to be done for pass groups, they auto-organise
        
    }
    
    /** Accept a visitor over the collection contents.
        @param visitor Visitor class which should be called back
        @param om The organisation mode which you want to iterate over.
            Note that this must have been included in an addOrganisationMode
            call before any renderables were added.
        */
    void acceptVisitor(QueuedRenderableVisitor visitor, OrganisationMode om)
    {
        debug(STDERR) std.stdio.stderr.writeln("QRC.acceptVisitor: ", om, cast(OrganisationMode)mOrganisationMode, ", ", (om & mOrganisationMode));
        if ((om & mOrganisationMode) == 0)
        {
            // try to fall back
            if (OrganisationMode.OM_PASS_GROUP & mOrganisationMode)
                om = OrganisationMode.OM_PASS_GROUP;
            else if (OrganisationMode.OM_SORT_ASCENDING & mOrganisationMode)
                om = OrganisationMode.OM_SORT_ASCENDING;
            else if (OrganisationMode.OM_SORT_DESCENDING & mOrganisationMode)
                om = OrganisationMode.OM_SORT_DESCENDING;
            else
                throw new InvalidParamsError(
                            "Organisation mode requested in acceptVistor was not notified "
                            "to this class ahead of time, therefore may not be supported.", 
                            "QueuedRenderableCollection.acceptVisitor");
        }
        
        final switch(om)
        {
            case OrganisationMode.OM_PASS_GROUP:
                acceptVisitorGrouped(visitor);
                break;
            case OrganisationMode.OM_SORT_DESCENDING:
                acceptVisitorDescending(visitor);
                break;
            case OrganisationMode.OM_SORT_ASCENDING:
                acceptVisitorAscending(visitor);
                break;
        }
        
    }
    
    /** Merge renderable collection. 
        */
    void merge( QueuedRenderableCollection rhs )
    {
        mSortedDescending.insert(rhs.mSortedDescending);
        
        foreach( k, srcGroup; rhs.mGrouped)
        {
            auto dstGroup = k in mGrouped;
            if (dstGroup is null)
            {
                //std::pair<PassGroupRenderableMap::iterator, bool> retPair;
                // Create new pass entry, build a new list
                // Note that this pass and list are never destroyed until the 
                // engine shuts down, or a pass is destroyed or has it's hash
                // recalculated, although the lists will be cleared
                //retPair = 
                mGrouped[k] = null;//FIXME Emulate std::map when adding existing key/value/whatever?
                
                //assert(retPair.second ,
                //       "Error inserting new pass entry into PassGroupRenderableMap");
                dstGroup = &mGrouped[k]; //retPair.first;
            }
            
            // Insert renderable
            (*dstGroup).insert(srcGroup);
        }
    }
}

/** Collection of renderables by priority.
    @remarks
        This class simply groups renderables for rendering. All the 
        renderables contained in this class are destined for the same
        RenderQueueGroup (coarse groupings like those between the main
        scene and overlays) and have the same priority (fine groupings
        for detailed overlap control).
    @par
        This class can order solid renderables by a number of criteria; 
        it can optimise them into groups based on pass to reduce render 
        state changes, or can sort them by ascending or descending view 
        depth. Transparent objects are always ordered by descending depth.
    @par
        To iterate over items in the collections held by this object 
        you should retrieve the collection in use (e.g. solids, solids with
        no shadows, transparents) and use the accept() method, providing 
        a class implementing QueuedRenderableVisitor.
    
    */
package class RenderPriorityGroup //: public RenderQueueAlloc
{
protected:
    
    /// Parent queue group
    RenderQueueGroup mParent;
    bool mSplitPassesByLightingType;
    bool mSplitNoShadowPasses;
    bool mShadowCastersNotReceivers;
    /// Solid pass list, used when no shadows, modulative shadows, or ambient passes for additive
    QueuedRenderableCollection mSolidsBasic;
    /// Solid per-light pass list, used with additive shadows
    QueuedRenderableCollection mSolidsDiffuseSpecular;
    /// Solid decal (texture) pass list, used with additive shadows
    QueuedRenderableCollection mSolidsDecal;
    /// Solid pass list, used when shadows are enabled but shadow receive is turned off for these passes
    QueuedRenderableCollection mSolidsNoShadowReceive;
    /// Unsorted transparent list
    QueuedRenderableCollection mTransparentsUnsorted;
    /// Transparent list
    QueuedRenderableCollection mTransparents;
    
    /// remove a pass entry from all collections
    void removePassEntry(Pass p)
    {
        mSolidsBasic.removePassGroup(p);
        mSolidsDiffuseSpecular.removePassGroup(p);
        mSolidsNoShadowReceive.removePassGroup(p);
        mSolidsDecal.removePassGroup(p);
        mTransparentsUnsorted.removePassGroup(p);
        mTransparents.removePassGroup(p); // shouldn't be any, but for completeness
    }
    
    /// Internal method for adding a solid renderable
    void addSolidRenderable(Technique pTech, Renderable rend, bool addToNoShadowMap)
    {
        auto pi = pTech.getPasses();
        debug(STDERR) std.stdio.stderr.writeln("RPGroup.addSolidRenderable: tech ", pTech.getName(), " has passes:", pi, ", ",
                                       rend.getMaterial().getAs().getName());
        
        QueuedRenderableCollection collection;
        if (addToNoShadowMap)
        {
            collection = mSolidsNoShadowReceive;
        }
        else
        {
            collection = mSolidsBasic;
        }
        
        
        //while (pi.hasMoreElements())
        foreach(p; pi)
        {
            debug(STDERR) std.stdio.stderr.writeln("RPGroup.addSolidRenderable");
            // Insert into solid list
            //Pass* p = pi.getNext();
            collection.addRenderable(p, rend);
        }
    }
    
    /// Internal method for adding a solid renderable
    void addSolidRenderableSplitByLightType(Technique pTech, Renderable rend)
    {
        // Divide the passes into the 3 categories
        auto pi = pTech.getIlluminationPasses();
        
        foreach(p; pi)
        {
            // Insert into solid list
            QueuedRenderableCollection collection = null;
            switch(p.stage)
            {
                case IlluminationStage.IS_AMBIENT:
                    collection = mSolidsBasic;
                    break;
                case IlluminationStage.IS_PER_LIGHT:
                    collection = mSolidsDiffuseSpecular;
                    break;
                case IlluminationStage.IS_DECAL:
                    collection = mSolidsDecal;
                    break;
                default:
                    assert(false, "should never happen"); // should never happen
            }
            
            collection.addRenderable(p.pass, rend);
        }
    }
    
    /// Internal method for adding an unsorted transparent renderable
    void addUnsortedTransparentRenderable(Technique pTech, Renderable rend)
    {
        foreach(p; pTech.getPasses())
        {
            // Insert into transparent list
            mTransparentsUnsorted.addRenderable(p, rend);
        }
    }
    
    /// Internal method for adding a transparent renderable
    void addTransparentRenderable(Technique pTech, Renderable rend)
    {
        foreach(p; pTech.getPasses())
        {
            // Insert into transparent list
            mTransparents.addRenderable(p, rend);
        }
    }
    
public:
    this(RenderQueueGroup parent, 
        bool splitPassesByLightingType,
        bool splitNoShadowPasses, 
        bool shadowCastersNotReceivers)
    {
        
        mParent = parent;
        mSplitPassesByLightingType = splitPassesByLightingType;
        mSplitNoShadowPasses = splitNoShadowPasses;
        mShadowCastersNotReceivers = shadowCastersNotReceivers;

        mSolidsBasic            = new QueuedRenderableCollection;
        mSolidsDiffuseSpecular  = new QueuedRenderableCollection;
        mSolidsDecal            = new QueuedRenderableCollection;
        mSolidsNoShadowReceive  = new QueuedRenderableCollection;
        mTransparentsUnsorted   = new QueuedRenderableCollection;
        mTransparents           = new QueuedRenderableCollection;
        
        // Initialise collection sorting options
        // this can become dynamic according to invocation later
        defaultOrganisationMode();
        
        // Transparents will always be sorted this way
        mTransparents.addOrganisationMode(QueuedRenderableCollection.OrganisationMode.OM_SORT_DESCENDING);
    }
    
    ~this() { }
    
    /** Get the collection of basic solids currently queued, this includes
            all solids when there are no shadows, or all solids which have shadow
            receiving enabled when using modulative shadows, or all ambient passes
            of solids which have shadow receive enabled for additive shadows. */
    QueuedRenderableCollection getSolidsBasic()
    { return mSolidsBasic; }
    /** Get the collection of solids currently queued per light (only applicable in 
            additive shadow modes). */
    QueuedRenderableCollection getSolidsDiffuseSpecular()
    { return mSolidsDiffuseSpecular; }
    /** Get the collection of solids currently queued for decal passes (only 
            applicable in additive shadow modes). */
    QueuedRenderableCollection getSolidsDecal()
    { return mSolidsDecal; }
    /** Get the collection of solids for which shadow receipt is disabled (only
            applicable when shadows are enabled). */
    QueuedRenderableCollection getSolidsNoShadowReceive()
    { return mSolidsNoShadowReceive; }
    /** Get the collection of transparent objects currently queued */
    QueuedRenderableCollection getTransparentsUnsorted()
    { return mTransparentsUnsorted; }
    /** Get the collection of transparent objects currently queued */
    QueuedRenderableCollection getTransparents()
    { return mTransparents; }
    
    
    /** Reset the organisation modes required for the solids in this group. 
        @remarks
            You can only do this when the group is empty, i.e. after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void resetOrganisationModes()
    {
        mSolidsBasic.resetOrganisationModes();
        mSolidsDiffuseSpecular.resetOrganisationModes();
        mSolidsDecal.resetOrganisationModes();
        mSolidsNoShadowReceive.resetOrganisationModes();
        mTransparentsUnsorted.resetOrganisationModes();
    }
    
    /** Add a required sorting / grouping mode for the solids in this group.
        @remarks
            You can only do this when the group is empty, i.e. after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void addOrganisationMode(QueuedRenderableCollection.OrganisationMode om)
    {
        mSolidsBasic.addOrganisationMode(om);
        mSolidsDiffuseSpecular.addOrganisationMode(om);
        mSolidsDecal.addOrganisationMode(om);
        mSolidsNoShadowReceive.addOrganisationMode(om);
        mTransparentsUnsorted.addOrganisationMode(om);
    }
    
    /** Set the sorting / grouping mode for the solids in this group to the default.
        @remarks
            You can only do this when the group is empty, i.e. after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void defaultOrganisationMode()
    {
        resetOrganisationModes();
        addOrganisationMode(QueuedRenderableCollection.OrganisationMode.OM_PASS_GROUP);
    }
    
    /** Add a renderable to this group. */
    void addRenderable(Renderable rend, Technique pTech)
    {
        debug(STDERR) std.stdio.stderr.writeln("RenderPriorityGroup.addRenderable:", rend, ", ", pTech);
        // Transparent and depth/colour settings mean depth sorting is required?
        // Note: colour write disabled with depth check/write enabled means
        //       setup depth buffer for other passes use.
        if (pTech.isTransparentSortingForced() || 
            (pTech.isTransparent() && 
            (!pTech.isDepthWriteEnabled() ||
            !pTech.isDepthCheckEnabled() ||
            pTech.hasColourWriteDisabled())))
        {
            if (pTech.isTransparentSortingEnabled())
                addTransparentRenderable(pTech, rend);
            else
                addUnsortedTransparentRenderable(pTech, rend);
        }
        else
        {
            if (mSplitNoShadowPasses &&
                mParent.getShadowsEnabled() &&
                (!pTech.getParent().getReceiveShadows() ||
              rend.getCastsShadows() && mShadowCastersNotReceivers))
            {
                // Add solid renderable and add passes to no-shadow group
                addSolidRenderable(pTech, rend, true);
            }
            else
            {
                if (mSplitPassesByLightingType && mParent.getShadowsEnabled())
                {
                    addSolidRenderableSplitByLightType(pTech, rend);
                }
                else
                {
                    addSolidRenderable(pTech, rend, false);
                }
            }
        }
        
    }
    
    /** Sorts the objects which have been added to the queue; transparent objects by their 
            depth in relation to the passed in Camera. */
    void sort(Camera cam)
    {
        mSolidsBasic.sort(cam);
        mSolidsDecal.sort(cam);
        mSolidsDiffuseSpecular.sort(cam);
        mSolidsNoShadowReceive.sort(cam);
        mTransparentsUnsorted.sort(cam);
        mTransparents.sort(cam);
    }
    
    /** Clears this group of renderables. 
        */
    void clear()
    {
        // Delete queue groups which are using passes which are to be
        // deleted, we won't need these any more and they clutter up 
        // the list and can cause problems with future clones
        synchronized(Pass.msPassGraveyardMutex)
        {
            // Hmm, a bit hacky but least obtrusive for now
            //OGRE_LOCK_MUTEX(Pass::msPassGraveyardMutex)
            Pass.PassSet graveyardList = Pass.getPassGraveyard();
            foreach (gi; graveyardList)
            {
                removePassEntry(gi);
            }
        }
        
        // Now remove any dirty passes, these will have their hashes recalculated
        // by the parent queue after all groups have been processed
        // If we don't do this, the std::map will become inconsistent for new insterts
        synchronized(Pass.msDirtyHashListMutex)
        {
            // Hmm, a bit hacky but least obtrusive for now
            //OGRE_LOCK_MUTEX(Pass::msDirtyHashListMutex)
            Pass.PassSet dirtyList = Pass.getDirtyHashList();
            foreach (di; dirtyList)
            {
                removePassEntry(di);
            }
        }
        // NB we do NOT clear the graveyard or the dirty list here, because 
        // it needs to be acted on for all groups, the parent queue takes 
        // care of this afterwards
        
        // Now empty the remaining collections
        // Note that groups don't get deleted, just emptied hence the difference
        // between the pass groups which are removed above, and clearing done
        // here
        mSolidsBasic.clear();
        mSolidsDecal.clear();
        mSolidsDiffuseSpecular.clear();
        mSolidsNoShadowReceive.clear();
        mTransparentsUnsorted.clear();
        mTransparents.clear();
        
    }
    
    /** Sets whether or not the queue will split passes by their lighting type,
        ie ambient, per-light and decal. 
        */
    void setSplitPassesByLightingType(bool split)
    {
        mSplitPassesByLightingType = split;
    }
    
    /** Sets whether or not passes which have shadow receive disabled should
            be separated. 
        */
    void setSplitNoShadowPasses(bool split)
    {
        mSplitNoShadowPasses = split;
    }
    
    /** Sets whether or not objects which cast shadows should be treated as
            never receiving shadows. 
        */
    void setShadowCastersCannotBeReceivers(bool ind)
    {
        mShadowCastersNotReceivers = ind;
    }
    
    /** Merge group of renderables. 
        */
    void merge( RenderPriorityGroup rhs )
    {
        mSolidsBasic.merge( rhs.mSolidsBasic );
        mSolidsDecal.merge( rhs.mSolidsDecal );
        mSolidsDiffuseSpecular.merge( rhs.mSolidsDiffuseSpecular );
        mSolidsNoShadowReceive.merge( rhs.mSolidsNoShadowReceive );
        mTransparentsUnsorted.merge( rhs.mTransparentsUnsorted );
        mTransparents.merge( rhs.mTransparents );
    }
}


/** A grouping level underneath RenderQueue which groups renderables
    to be issued at coarsely the same time to the renderer.
    @remarks
        Each instance of this class itself hold RenderPriorityGroup instances, 
        which are the groupings of renderables by priority for fine control
        of ordering (not required for most instances).
    */
class RenderQueueGroup //: public RenderQueueAlloc
{
public:
    //typedef map<ushort, RenderPriorityGroup*, std::less<ushort> >::type PriorityMap;
    //typedef MapIterator<PriorityMap> PriorityMapIterator;
    //typedef ConstMapIterator<PriorityMap> ConstPriorityMapIterator;
    
    alias RenderPriorityGroup[ushort] PriorityMap;
    //alias SortedMap!(ushort, RenderPriorityGroup) PriorityMap;
    
protected:
    RenderQueue mParent;
    bool mSplitPassesByLightingType;
    bool mSplitNoShadowPasses;
    bool mShadowCastersNotReceivers;
    /// Map of RenderPriorityGroup objects
    PriorityMap mPriorityGroups;
    /// Whether shadows are enabled for this queue
    bool mShadowsEnabled;
    /// Bitmask of the organisation modes requested (for new priority groups)
    ubyte mOrganisationMode;
    
    
public:
    this(RenderQueue parent,
                     bool splitPassesByLightingType,
                     bool splitNoShadowPasses,
                     bool shadowCastersNotReceivers) 
    {
        mParent = parent;
        mSplitPassesByLightingType = splitPassesByLightingType;
        mSplitNoShadowPasses = splitNoShadowPasses;
        mShadowCastersNotReceivers = shadowCastersNotReceivers;
        mShadowsEnabled = true;
        mOrganisationMode = 0;
    }
    
    ~this() {
        // destroy contents now
        foreach (k,v; mPriorityGroups)
        {
            destroy(v);
        }
    }
    
    /* * Get an iterator for browsing through child contents. */
    /*PriorityMapIterator getIterator()
    {
        return PriorityMapIterator(mPriorityGroups.begin(), mPriorityGroups.end());
    }*/
    
    /* * Get a const iterator for browsing through child contents. */
    /*ConstPriorityMapIterator getIterator()
    {
        return ConstPriorityMapIterator(mPriorityGroups.begin(), mPriorityGroups.end());
    }*/
    
    //TODO Passing without ref so cant modify outside RenderQueueGroup, right?
    PriorityMap getPriorityMap()
    {
        return mPriorityGroups;
    }
    
    /** Add a renderable to this group, with the given priority. */
    void addRenderable(Renderable pRend, Technique pTech, ushort priority)
    {
        debug(STDERR) std.stdio.stderr.writeln("RenderQueueGroup.addRenderable:", pRend, ", ", priority);
        // Check if priority group is there
        auto i = priority in mPriorityGroups;
        RenderPriorityGroup pPriorityGrp;
        if (i is null)
        {
            // Missing, create
            pPriorityGrp = new RenderPriorityGroup(this, 
                                                        mSplitPassesByLightingType,
                                                        mSplitNoShadowPasses, 
                                                        mShadowCastersNotReceivers);
            if (mOrganisationMode)
            {
                pPriorityGrp.resetOrganisationModes();
                pPriorityGrp.addOrganisationMode(cast(QueuedRenderableCollection.OrganisationMode)mOrganisationMode);
            }
            
            mPriorityGroups[priority] = pPriorityGrp;
        }
        else
        {
            pPriorityGrp = *i;
        }
        
        // Add
        pPriorityGrp.addRenderable(pRend, pTech);
        debug(STDERR) std.stdio.stderr.writeln("\tIn group:", mPriorityGroups);
    }
    
    /** Clears this group of renderables. 
        @param destroy
            If false, doesn't delete any priority groups, just empties them. Saves on 
            memory deallocations since the chances are roughly the same kinds of 
            renderables are going to be sent to the queue again next time. If
            true, completely destroys.
        */
    void clear(bool _destroy = false)
    {
        foreach (k,v; mPriorityGroups)
        {
            if (_destroy)
                destroy(v);
            else
                v.clear();
        }
        
        if (_destroy)
            mPriorityGroups.clear();
        
    }
    
    /** Indicate whether a given queue group will be doing any
        shadow setup.
        @remarks
        This method allows you to inform the queue about a queue group, and to 
        indicate whether this group will require shadow processing of any sort.
        In order to preserve rendering order, OGRE has to treat queue groups
        as very separate elements of the scene, and this can result in it
        having to duplicate shadow setup for each group. therefore, if you
        know that a group which you are using will never need shadows, you
        should preregister the group using this method in order to improve
        the performance.
        */
    void setShadowsEnabled(bool enabled) { mShadowsEnabled = enabled; }
    
    /** Are shadows enabled for this queue? */
    bool getShadowsEnabled(){ return mShadowsEnabled; }
    
    /** Sets whether or not the queue will split passes by their lighting type,
        ie ambient, per-light and decal. 
        */
    void setSplitPassesByLightingType(bool split)
    {
        mSplitPassesByLightingType = split;
        foreach (k,v; mPriorityGroups)
        {
            v.setSplitPassesByLightingType(split);
        }
    }
    /** Sets whether or not the queue will split passes which have shadow receive
        turned off (in their parent material), which is needed when certain shadow
        techniques are used.
        */
    void setSplitNoShadowPasses(bool split)
    {
        mSplitNoShadowPasses = split;
        foreach (k,v; mPriorityGroups)
        {
            v.setSplitNoShadowPasses(split);
        }
    }
    /** Sets whether or not objects which cast shadows should be treated as
        never receiving shadows. 
        */
    void setShadowCastersCannotBeReceivers(bool ind)
    {
        mShadowCastersNotReceivers = ind;
        foreach (k,v; mPriorityGroups)
        {
            v.setShadowCastersCannotBeReceivers(ind);
        }
    }
    /** Reset the organisation modes required for the solids in this group. 
        @remarks
            You can only do this when the group is empty, ie after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void resetOrganisationModes()
    {
        mOrganisationMode = 0;
        
        foreach (k,v; mPriorityGroups)
        {
            v.resetOrganisationModes();
        }
    }
    
    /** Add a required sorting / grouping mode for the solids in this group.
        @remarks
            You can only do this when the group is empty, ie after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void addOrganisationMode(QueuedRenderableCollection.OrganisationMode om)
    {
        mOrganisationMode |= om;
        
        foreach (k,v; mPriorityGroups)
        {
            v.addOrganisationMode(om);
        }
    }
    
    /** Setthe  sorting / grouping mode for the solids in this group to the default.
        @remarks
            You can only do this when the group is empty, ie after clearing the 
            queue.
        @see QueuedRenderableCollection::OrganisationMode
        */
    void defaultOrganisationMode()
    {
        mOrganisationMode = 0;
        
        foreach (k,v; mPriorityGroups)
        {
            v.defaultOrganisationMode();
        }
    }
    
    /** Merge group of renderables. 
        */
    void merge( RenderQueueGroup rhs )
    {
        //ConstPriorityMapIterator it = rhs.getIterator();
        
        //while( it.hasMoreElements() )
        foreach(priority, pSrcPriorityGrp; rhs.getPriorityMap())
        {
            RenderPriorityGroup pDstPriorityGrp;
            
            // Check if priority group is there
            auto i = priority in mPriorityGroups;
            if (i is null)
            {
                // Missing, create
                pDstPriorityGrp = new RenderPriorityGroup(this, 
                                                               mSplitPassesByLightingType,
                                                               mSplitNoShadowPasses, 
                                                               mShadowCastersNotReceivers);
                if (mOrganisationMode)
                {
                    pDstPriorityGrp.resetOrganisationModes();
                    pDstPriorityGrp.addOrganisationMode(cast(QueuedRenderableCollection.OrganisationMode)mOrganisationMode);
                }
                
                mPriorityGroups[priority] = pDstPriorityGrp;
            }
            else
            {
                pDstPriorityGrp = *i;
            }
            
            // merge
            pDstPriorityGrp.merge( pSrcPriorityGrp );
        }
    }
}

/** @} */
/** @} */