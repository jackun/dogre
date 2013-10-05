module ogre.scene.scenequery;

import std.algorithm;
import std.array;
import ogre.math.plane;
import ogre.compat;
import ogre.math.ray;
import ogre.math.sphere;
import ogre.math.axisalignedbox;
import ogre.math.vector;
import ogre.rendersystem.renderoperation;
import ogre.scene.scenemanager;
import ogre.scene.movableobject;
import ogre.exception;

/** A class for performing queries on a scene.
    @remarks
        This is an abstract class for performing a query on a scene, i.e. to retrieve
        a list of objects and/or world geometry sections which are potentially intersecting a
        given region. Note the use of the word 'potentially': the results of a scene query
        are generated based on bounding volumes, and as such are not correct at a triangle
        level; the user of the SceneQuery is expected to filter the results further if
        greater accuracy is required.
    @par
        Different SceneManagers will implement these queries in different ways to
        exploit their particular scene organisation, and thus will provide their own
        concrete subclasses. In fact, these subclasses will be derived from subclasses
        of this class rather than directly because there will be region-type classes
        in between.
    @par
        These queries could have just been implemented as methods on the SceneManager,
        however, they are wrapped up as objects to allow 'compilation' of queries
        if deemed appropriate by the implementation; i.e. each concrete subclass may
        precalculate information (such as fixed scene partitions involved in the query)
        to speed up the repeated use of the query.
    @par
        You should never try to create a SceneQuery object yourself, they should be created
        using the SceneManager interfaces for the type of query required, e.g.
        SceneManager::createSphereSceneQuery.
    */
class SceneQuery //: public SceneMgtAlloc
{
public:
    /** This type can be used by collaborating applications & SceneManagers to 
            agree on the type of world geometry to be returned from queries. Not all
            these types will be supported by all SceneManagers; once the application
            has decided which SceneManager specialisation to use, it is expected that 
            it will know which type of world geometry abstraction is available to it.
        */
    enum WorldFragmentType {
        /// Return no world geometry hits at all
        WFT_NONE,
        /// Return pointers to convex plane-bounded regions
        WFT_PLANE_BOUNDED_REGION,
        /// Return a single intersection point (typically RaySceneQuery only)
        WFT_SINGLE_INTERSECTION,
        /// Custom geometry as defined by the SceneManager
        WFT_CUSTOM_GEOMETRY,
        /// General RenderOperation structure
        WFT_RENDER_OPERATION
    }
    
    /** Represents part of the world geometry that is a result of a SceneQuery. 
        @remarks
            Since world geometry is normally vast and sprawling, we need a way of
            retrieving parts of it based on a query. That is what this struct is for;
            note there are potentially as many data structures for world geometry as there
            are SceneManagers, however this structure includes a few common abstractions as 
            well as a more general format.
        @par
            The type of world fragment that is returned from a query depends on the
            SceneManager, and the option set using SceneQuery::setWorldFragmentType. 
            You can see what fragment types are supported on the query in question by
            calling SceneQuery::getSupportedWorldFragmentTypes().
        */
    struct WorldFragment {
        /// The type of this world fragment
        WorldFragmentType fragmentType;
        /// Single intersection point, only applicable for WFT_SINGLE_INTERSECTION
        Vector3 singleIntersection;
        /// Planes bounding a convex region, only applicable for WFT_PLANE_BOUNDED_REGION
        //list<Plane>::type* planes;
        Plane[] planes;
        /// Custom geometry block, only applicable for WFT_CUSTOM_GEOMETRY
        void* geometry;
        /// General render operation structure, fallback if nothing else is available
        RenderOperation renderOp;
    }
    
protected:
    SceneManager mParentSceneMgr;
    uint mQueryMask;
    uint mQueryTypeMask;
    //set<WorldFragmentType>::type mSupportedWorldFragments;
    WorldFragmentType[] mSupportedWorldFragments;
    WorldFragmentType mWorldFragmentType;
    
public:
    /** Standard constructor, should be called by SceneManager. */
    this(SceneManager mgr)
    {
        mParentSceneMgr = mgr;
        mQueryMask = 0xFFFFFFFF; 
        mWorldFragmentType = WorldFragmentType.WFT_NONE;
        // default type mask to everything except lights & fx (previous behaviour)
        mQueryTypeMask = (0xFFFFFFFF & ~SceneManager.FX_TYPE_MASK) 
            & ~SceneManager.LIGHT_TYPE_MASK;
    }
    
    ~this() {}
    
    /** Sets the mask for results of this query.
        @remarks
            This method allows you to set a 'mask' to limit the results of this
            query to certain types of result. The actual meaning of this value is
            up to the application; basically MovableObject instances will only be returned
            from this query if a bitwise AND operation between this mask value and the
            MovableObject::getQueryFlags value is non-zero. The application will
            have to decide what each of the bits means.
        */
    void setQueryMask(uint mask)
    {
        mQueryMask = mask;
    }
    /** Returns the current mask for this query. */
    uint getQueryMask()
    {
        return mQueryMask;
    }
    
    /** Sets the type mask for results of this query.
        @remarks
            This method allows you to set a 'type mask' to limit the results of this
            query to certain types of objects. Whilst setQueryMask deals with flags
            set per instance of object, this method deals with setting a mask on 
            flags set per type of object. Both may exclude an object from query
            results.
        */
    void setQueryTypeMask(uint mask)
    {
        mQueryTypeMask = mask;
    }
    /** Returns the current mask for this query. */
    uint getQueryTypeMask()
    {
        return mQueryTypeMask;
    }
    
    /** Tells the query what kind of world geometry to return from queries;
            often the full renderable geometry is not what is needed. 
        @remarks
            The application receiving the world geometry is expected to know 
            what to do with it; inevitably this means that the application must 
            have knowledge of at least some of the structures
            used by the custom SceneManager.
        @par
            The default setting is WFT_NONE.
        */
    void setWorldFragmentType(WorldFragmentType wft)
    {
        // Check supported
        if (mSupportedWorldFragments.find(wft).empty)
        {
            throw new InvalidParamsError("This world fragment type is not supported.",
                                         "SceneQuery.setWorldFragmentType");
        }
        mWorldFragmentType = wft;
    }
    
    /** Gets the current world fragment types to be returned from the query. */
    WorldFragmentType getWorldFragmentType()
    {
        return mWorldFragmentType;
    }
    
    /** Returns the types of world fragments this query supports. */
    //set<WorldFragmentType>::type* 
    WorldFragmentType[] getSupportedWorldFragmentTypes()
    {
        return mSupportedWorldFragments;
    }
}

/** This optional class allows you to receive per-result callbacks from
        SceneQuery executions instead of a single set of consolidated results.
    @remarks
        You should override this with your own subclass. Note that certain query
        classes may refine this listener interface.
    */
interface SceneQueryListener
{
    /** Called when a MovableObject is returned by a query.
        @remarks
            The implementor should return 'true' to continue returning objects,
            or 'false' to abandon any further results from this query.
        */
    bool queryResult(MovableObject object);
    /** Called when a WorldFragment is returned by a query.
        @remarks
            The implementor should return 'true' to continue returning objects,
            or 'false' to abandon any further results from this query.
        */
    bool queryResult(SceneQuery.WorldFragment fragment);
}

//typedef list<MovableObject*>::type SceneQueryResultMovableList;
//typedef list<SceneQuery::WorldFragment*>::type SceneQueryResultWorldFragmentList;
alias MovableObject[] SceneQueryResultMovableList;
alias SceneQuery.WorldFragment[] SceneQueryResultWorldFragmentList;

/** Holds the results of a scene query. */
struct SceneQueryResult //: public SceneMgtAlloc
{
    /// List of movable objects in the query (entities, particle systems etc)
    SceneQueryResultMovableList movables;
    /// List of world fragments
    SceneQueryResultWorldFragmentList worldFragments;
}

/** Abstract class defining a query which returns single results from a region. 
    @remarks
        This class is simply a generalisation of the subtypes of query that return 
        a set of individual results in a region. See the SceneQuery class for abstract
        information, and subclasses for the detail of each query type.
    */
class RegionSceneQuery : SceneQuery, SceneQueryListener
{
protected:
    SceneQueryResult *mLastResult;
public:
    /** Standard constructor, should be called by SceneManager. */
    this(SceneManager mgr)
    {
        super(mgr);
    }
    
    ~this()
    {
        clearResults();
    }
    
    /** Executes the query, returning the results back in one list.
        @remarks
            This method executes the scene query as configured, gathers the results
            into one structure and returns a reference to that structure. These
            results will also persist in this query object until the next query is
            executed, or clearResults() is called. An more lightweight version of
            this method that returns results through a listener is also available.
        */
    SceneQueryResult* execute()
    {
        clearResults();
        mLastResult = new SceneQueryResult();
        // Call callback version with self as listener
        execute(this);
        return mLastResult;
    }
    
    /** Executes the query and returns each match through a listener interface. 
        @remarks
            Note that this method does not store the results of the query internally 
            so does not update the 'last result' value. This means that this version of
            execute is more lightweight and therefore more efficient than the version 
            which returns the results as a collection.
        */
    abstract void execute(SceneQueryListener listener);
    
    /** Gets the results of the last query that was run using this object, provided
            the query was executed using the collection-returning version of execute. 
        */
    SceneQueryResult* getLastResults()
    {
        assert(mLastResult);
        return mLastResult;
    }
    
    /** Clears the results of the last query execution.
        @remarks
            You only need to call this if you specifically want to free up the memory
            used by this object to hold the last query results. This object clears the
            results itself when executing and when destroying itself.
        */
    void clearResults()
    {
        if (mLastResult)
        {
            destroy(mLastResult);
        }
        mLastResult = null;
    }
    
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(MovableObject obj)
    {
        // Add to internal list
        mLastResult.movables.insert(obj);
        // Continue
        return true;
    }
    
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(SceneQuery.WorldFragment fragment)
    {
        // Add to internal list
        mLastResult.worldFragments.insert(fragment);
        // Continue
        return true;
    }
}

/** Specialises the SceneQuery class for querying within an axis aligned box. */
class AxisAlignedBoxSceneQuery : RegionSceneQuery
{
protected:
    AxisAlignedBox mAABB;
public:
    this(SceneManager mgr)
    {
        super(mgr);
    }
    
    ~this() {}
    
    /** Sets the size of the box you wish to query. */
    void setBox(AxisAlignedBox box)
    {
        mAABB = box;
    }
    
    /** Gets the box which is being used for this query. */
   AxisAlignedBox getBox()
    {
        return mAABB;
    }
}

/** Specialises the SceneQuery class for querying within a sphere. */
class SphereSceneQuery : RegionSceneQuery
{
protected:
    Sphere mSphere;
public:
    this(SceneManager mgr)
    {
        super(mgr);
    }
    ~this(){}
    /** Sets the sphere which is to be used for this query. */
    void setSphere(Sphere sphere)
    {
        mSphere = sphere;
    }
    
    /** Gets the sphere which is being used for this query. */
   Sphere getSphere()
    {
        return mSphere;
    }   
}

/** Specialises the SceneQuery class for querying within a plane-bounded volume. 
    */
//TODO PlaneBoundedVolumeListSceneQuery ref or not?
class PlaneBoundedVolumeListSceneQuery : RegionSceneQuery
{
protected:
    PlaneBoundedVolumeList mVolumes;
public:
    this(SceneManager mgr)
    {
        super(mgr);
    }
    ~this(){}
    /** Sets the volume which is to be used for this query. */
    void setVolumes(PlaneBoundedVolumeList volumes)
    {
        mVolumes = volumes;
    }
    
    /** Gets the volume which is being used for this query. */
    PlaneBoundedVolumeList getVolumes()
    {
        return mVolumes;
    }   
}


/*
    /// Specialises the SceneQuery class for querying within a pyramid. 
    class _OgreExport PyramidSceneQuery : public RegionSceneQuery
    {
    public:
        PyramidSceneQuery(SceneManager* mgr);
        ~PyramidSceneQuery();
    };
    */

/** Alternative listener class for dealing with RaySceneQuery.
    @remarks
        Because the RaySceneQuery returns results in an extra bit of information, namely
        distance, the listener interface must be customised from the standard SceneQueryListener.
    */
interface RaySceneQueryListener 
{
    /** Called when a movable objects intersects the ray.
        @remarks
            As with SceneQueryListener, the implementor of this method should return 'true'
            if further results are required, or 'false' to abandon any further results from
            the current query.
        */
    bool queryResult(MovableObject obj, Real distance);
    
    /** Called when a world fragment is intersected by the ray. 
        @remarks
            As with SceneQueryListener, the implementor of this method should return 'true'
            if further results are required, or 'false' to abandon any further results from
            the current query.
        */
    bool queryResult(SceneQuery.WorldFragment fragment, Real distance);   
}

/** This struct allows a single comparison of result data no matter what the type */
struct RaySceneQueryResultEntry
{
    /// Distance along the ray
    Real distance;
    /// The movable, or NULL if this is not a movable result
    MovableObject movable;
    /// The world fragment, or NULL if this is not a fragment result
    SceneQuery.WorldFragment* worldFragment;
    /// Comparison operator for sorting
    //bool operator < (RaySceneQueryResultEntry& rhs)
    //TODO operator <
    Real opCmp (RaySceneQueryResultEntry rhs)
    {
        return distance - rhs.distance;
    }
}

//typedef vector<RaySceneQueryResultEntry>::type RaySceneQueryResult;
alias RaySceneQueryResultEntry[] RaySceneQueryResult;

/** Specialises the SceneQuery class for querying along a ray. */
class RaySceneQuery : SceneQuery, RaySceneQueryListener
{
protected:
    Ray mRay;
    bool mSortByDistance;
    ushort mMaxResults;
    RaySceneQueryResult mResult;
    
public:
    this(SceneManager mgr)
    {
        super(mgr);
        mSortByDistance = false;
        mMaxResults = 0;
    }
    ~this(){}
    
    /** Sets the ray which is to be used for this query. */
    void setRay(Ray ray)
    {
        mRay = ray;
    }
    /** Gets the ray which is to be used for this query. */
    Ray getRay()
    {
        return mRay;
    }
    /** Sets whether the results of this query will be sorted by distance along the ray.
        @remarks
            Often you want to know what was the first object a ray intersected with, and this 
            method allows you to ask the query to sort the results so that the nearest results
            are listed first.
        @par
            Note that because the query returns results based on bounding volumes, the ray may not
            actually intersect the detail of the objects returned from the query, just their 
            bounding volumes. For this reason the caller is advised to use more detailed 
            intersection tests on the results if a more accurate result is required; OGRE uses 
            bounds checking in order to give the most speedy results since not all applications 
            need extreme accuracy.
        @param sort If true, results will be sorted.
        @param maxresults If sorting is enabled, this value can be used torain the maximum number
            of results that are returned. Please note (as above) that the use of bounding volumes mean that
            accuracy is not guaranteed; if in doubt, allow more results and filter them in more detail.
            0 means unlimited results.
        */
    void setSortByDistance(bool sort, ushort maxresults = 0)
    {
        mSortByDistance = sort;
        mMaxResults = maxresults;
    }
    /** Gets whether the results are sorted by distance. */
    bool getSortByDistance()
    {
        return mSortByDistance;
    }
    /** Gets the maximum number of results returned from the query (only relevant if 
        results are being sorted) */
    ushort getMaxResults()
    {
        return mMaxResults;
    }
    /** Executes the query, returning the results back in one list.
        @remarks
            This method executes the scene query as configured, gathers the results
            into one structure and returns a reference to that structure. These
            results will also persist in this query object until the next query is
            executed, or clearResults() is called. An more lightweight version of
            this method that returns results through a listener is also available.
        */
    RaySceneQueryResult execute()
    {
        // Clear without freeing the vector buffer
        mResult.clear();
        
        // Call callback version with self as listener
        this.execute(this);
        
        if (mSortByDistance)
        {
            if (mMaxResults != 0 && mMaxResults < mResult.length)
            {
                // Partially sort the N smallest elements, discard others
                //std::partial_sort(mResult.begin(), mResult.begin()+mMaxResults, mResult.end());
                //std.algorithm.partialSort(mResult[], mMaxResults); //FIXME Some errors
                //std.algorithm.sort(mResult[].mMaxResults)); // ) won't give out-of-range error
                std.algorithm.sort(mResult[0..mMaxResults]); // but we already did range checks
                mResult.length = mMaxResults;
            }
            else
            {
                // Sort entire result array
                //std::sort(mResult.begin(), mResult.end());
                std.algorithm.sort(mResult);//TODO Specify SortStrategy?
            }
        }
        
        return mResult;
    }
    
    /** Executes the query and returns each match through a listener interface. 
        @remarks
            Note that this method does not store the results of the query internally 
            so does not update the 'last result' value. This means that this version of
            execute is more lightweight and therefore more efficient than the version 
            which returns the results as a collection.
        */
    abstract void execute(RaySceneQueryListener listener);
    
    /** Gets the results of the last query that was run using this object, provided
            the query was executed using the collection-returning version of execute. 
        */
    RaySceneQueryResult getLastResults()
    {
        return mResult;
    }
    /** Clears the results of the last query execution.
        @remarks
            You only need to call this if you specifically want to free up the memory
            used by this object to hold the last query results. This object clears the
            results itself when executing and when destroying itself.
        */
    void clearResults()
    {
        // C++ idiom to free vector buffer: swap with empty vector
        //RaySceneQueryResult().swap(mResult);
        mResult.clear();
    }
    
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(MovableObject obj, Real distance)
    {
        // Add to internal list
        RaySceneQueryResultEntry dets;
        dets.distance = distance;
        dets.movable = obj;
        dets.worldFragment = null;
        mResult.insert(dets);
        // Continue
        return true;
    }
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(SceneQuery.WorldFragment fragment, Real distance)
    {
        // Add to internal list
        RaySceneQueryResultEntry dets;
        dets.distance = distance;
        dets.movable = null;
        dets.worldFragment = &fragment;
        mResult.insert(dets);
        // Continue
        return true;
    }
}

/** Alternative listener class for dealing with IntersectionSceneQuery.
    @remarks
        Because the IntersectionSceneQuery returns results in pairs, rather than singularly,
        the listener interface must be customised from the standard SceneQueryListener.
    */
interface IntersectionSceneQueryListener 
{
    /** Called when 2 movable objects intersect one another.
        @remarks
            As with SceneQueryListener, the implementor of this method should return 'true'
            if further results are required, or 'false' to abandon any further results from
            the current query.
        */
    bool queryResult(MovableObject first, MovableObject second);
    
    /** Called when a movable intersects a world fragment. 
        @remarks
            As with SceneQueryListener, the implementor of this method should return 'true'
            if further results are required, or 'false' to abandon any further results from
            the current query.
        */
    bool queryResult(MovableObject movable, SceneQuery.WorldFragment fragment);
    
    /* NB there are no results for world fragments intersecting other world fragments;
           it is assumed that world geometry is either static or at least that self-intersections
           are irrelevant or dealt with elsewhere (such as the custom scene manager) */
    
}

//typedef std::pair<MovableObject*, MovableObject*> SceneQueryMovableObjectPair;
//typedef std::pair<MovableObject*, SceneQuery::WorldFragment*> SceneQueryMovableObjectWorldFragmentPair;
//typedef list<SceneQueryMovableObjectPair>::type SceneQueryMovableIntersectionList;
//typedef list<SceneQueryMovableObjectWorldFragmentPair>::type SceneQueryMovableWorldFragmentIntersectionList;

alias pair!(MovableObject, MovableObject) SceneQueryMovableObjectPair;
alias pair!(MovableObject, SceneQuery.WorldFragment) SceneQueryMovableObjectWorldFragmentPair;
alias SceneQueryMovableObjectPair[] SceneQueryMovableIntersectionList;
alias SceneQueryMovableObjectWorldFragmentPair[] SceneQueryMovableWorldFragmentIntersectionList;

/** Holds the results of an intersection scene query (pair values). */
struct IntersectionSceneQueryResult //: public SceneMgtAlloc
{
    /// List of movable / movable intersections (entities, particle systems etc)
    SceneQueryMovableIntersectionList movables2movables;
    /// List of movable / world intersections
    SceneQueryMovableWorldFragmentIntersectionList movables2world;
}

/** Separate SceneQuery class to query for pairs of objects which are
        possibly intersecting one another.
    @remarks
        This SceneQuery subclass considers the whole world and returns pairs of objects
        which are close enough to each other that they may be intersecting. Because of
        this slightly different focus, the return types and listener interface are
        different for this class.
    */
class IntersectionSceneQuery : SceneQuery, IntersectionSceneQueryListener 
{
protected:
    IntersectionSceneQueryResult* mLastResult;
public:
    this(SceneManager mgr)
    {
        super(mgr);
    }
    ~this()
    {
        clearResults();
    }
    
    /** Executes the query, returning the results back in one list.
        @remarks
            This method executes the scene query as configured, gathers the results
            into one structure and returns a reference to that structure. These
            results will also persist in this query object until the next query is
            executed, or clearResults() is called. An more lightweight version of
            this method that returns results through a listener is also available.
        */
    IntersectionSceneQueryResult* execute()
    {
        clearResults();
        mLastResult = new IntersectionSceneQueryResult();
        // Call callback version with self as listener
        execute(this);
        return mLastResult;
    }
    
    /** Executes the query and returns each match through a listener interface. 
        @remarks
            Note that this method does not store the results of the query internally 
            so does not update the 'last result' value. This means that this version of
            execute is more lightweight and therefore more efficient than the version 
            which returns the results as a collection.
        */
    abstract void execute(IntersectionSceneQueryListener listener);
    
    /** Gets the results of the last query that was run using this object, provided
            the query was executed using the collection-returning version of execute. 
        */
    IntersectionSceneQueryResult* getLastResults()
    {
        assert(mLastResult);
        return mLastResult;
    }
    /** Clears the results of the last query execution.
        @remarks
            You only need to call this if you specifically want to free up the memory
            used by this object to hold the last query results. This object clears the
            results itself when executing and when destroying itself.
        */
    void clearResults()
    {
        if (mLastResult)
        {
            destroy(mLastResult);
        }
        mLastResult = null;
    }
    
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(MovableObject first, MovableObject second)
    {
        // Add to internal list
        mLastResult.movables2movables.insert(
            SceneQueryMovableObjectPair(first, second)
            );
        // Continue
        return true;
    }
    /** Self-callback in order to deal with execute which returns collection. */
    bool queryResult(MovableObject movable, SceneQuery.WorldFragment fragment)
    {
        // Add to internal list
        mLastResult.movables2world.insert(
            SceneQueryMovableObjectWorldFragmentPair(movable, fragment)
            );
        // Continue
        return true;
    }
}
